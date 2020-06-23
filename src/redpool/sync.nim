import times, net
import redis

type
  RedisConn = ref object
    conn: Redis
    taken: float

  RedisPool* = ref object
    conns: seq[RedisConn]
    host: string
    port: Port
    timeout: float
    maxConns: int

proc newRedisConn(pool: RedisPool; taken=false): RedisConn =
  result = RedisConn(
    conn: open(pool.host, pool.port),
    taken: if taken: epochTime() else: 0
  )

proc newRedisPool*(size: int; maxConns=10; timeout=10.0;
                   host="localhost"; port=6379): RedisPool =
  result = RedisPool(
    maxConns: maxConns,
    host: host,
    port: Port(port),
    timeout: timeout
  )

  for n in 0 ..< size:
    result.conns.add newRedisConn(result)

proc acquire*(pool: RedisPool): Redis =
  let now = epochTime()
  for rconn in pool.conns:
    if now - rconn.taken > pool.timeout:
      rconn.taken = now
      return rconn.conn

  let newConn = newRedisConn(pool, taken=true)
  pool.conns.add newConn
  return newConn.conn

proc release*(pool: RedisPool; conn: Redis) =
  for i, rconn in pool.conns:
    if rconn.conn == conn:
      if pool.conns.len > pool.maxConns:
        pool.conns.del(i)
      else:
        rconn.taken = 0
      break

template withAcquire*(pool: RedisPool; conn, body: untyped) =
  let `conn` {.inject.} = pool.acquire()
  try:
    body
  finally:
    pool.release(`conn`)