import asyncdispatch, times, net
import redis

type
  RedisConn = ref object
    conn: AsyncRedis
    taken: float

  RedisPool* = ref object
    conns: seq[RedisConn]
    host: string
    port: Port
    timeout: float
    password: string
    maxConns: int

proc newRedisConn(pool: RedisPool; taken=false): Future[RedisConn] {.async.} =
  result = RedisConn(
    conn: await openAsync(pool.host, pool.port),
    taken: if taken: epochTime() else: 0
  )
  
  if (len(pool.password) != 0):
    await result.conn.auth(pool.password)

proc newRedisPool*(size: int; maxConns=10; timeout=10.0;
                   host="localhost"; port=6379; password=""): Future[RedisPool] {.async.} =
  result = RedisPool(
    maxConns: maxConns,
    host: host,
    port: Port(port),
    timeout: timeout,
    password: password
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

proc release*(pool: RedisPool; conn: AsyncRedis; drop=false) {.async.} =
  for i, rconn in pool.conns:
    if rconn.conn == conn:
      if pool.conns.len > pool.maxConns or drop:
        pool.conns.del(i)
        await conn.quit()
      else:
        rconn.taken = 0
      break

template withAcquire*(pool: RedisPool; conn, body: untyped) =
  var badConnection = false
  let `conn` {.inject.} = await pool.acquire()
  try:
    body
  except ReplyError, RedisError:
    badConnection = true
  finally:
    await pool.release(`conn`, badConnection)

when isMainModule:
  proc main {.async.} =
    let pool = await newRedisPool(1)
    let conn = await pool.acquire()
    echo await conn.ping()
    await pool.release(conn)

    pool.withAcquire(conn2):
      echo await conn2.ping()

  waitFor main()
