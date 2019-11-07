import asyncdispatch, times, net
import redis

type
  RedisConn = ref object
    conn: AsyncRedis
    taken: float

  RedisPool = ref object
    conns: seq[RedisConn]
    host: string
    port: Port
    timeout: float
    maxConns: int

proc newRedisConn(pool: RedisPool; taken=false): Future[RedisConn] {.async.} =
  result = RedisConn(
    conn: await openAsync(pool.host, pool.port),
    taken: if taken: epochTime() else: 0
  )

proc newRedisPool*(size: int; maxConns=10; timeout=10.0;
                   host="localhost"; port=6379): Future[RedisPool] {.async.} =
  result = RedisPool(
    maxConns: maxConns,
    host: host,
    port: Port(port),
    timeout: timeout
  )

  for n in 0 ..< size:
    result.conns.add await newRedisConn(result)

proc acquire*(pool: RedisPool): Future[AsyncRedis] {.async.} =
  let now = epochTime()
  for rconn in pool.conns:
    if now - rconn.taken > pool.timeout:
      rconn.taken = now
      return rconn.conn

  let newConn = await newRedisConn(pool, taken=true)
  pool.conns.add newConn
  return newConn.conn

proc release*(pool: RedisPool; conn: AsyncRedis) =
  for i, rconn in pool.conns:
    if rconn.conn == conn:
      if pool.conns.len > pool.maxConns:
        pool.conns.del(i)
      else:
        rconn.taken = 0
      break

when isMainModule:
  proc main {.async.} =
    let pool = await newRedisPool(1)
    let conn = await pool.acquire()
    echo await conn.ping()
    pool.release(conn)

  waitFor main()
