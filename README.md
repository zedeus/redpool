# redpool

Simple Redis connection pool.

The `timeout` argument allows connections to be reused after a given time, in
case they don't get released properly. The `maxConn` argument sets a soft
limit, which destroys connection objects when released if the limit has been
reached. The `withAcquire` template can be used to automatically acquire and
release a connection, but note that with Nim versions below 1.3.1, the
`acquire` call is `waitFor`'d since `async` wasn't allowed inside templates
and macros before that.

# Usage

```nim
import asyncdispatch, redis, redpool

proc main {.async.} =
  let pool = await newRedisPool(5, timeout=4, maxConns=7)

  # manual acquire
  let conn = await pool.acquire()
  echo await conn.ping()
  await pool.release(conn)

  # acquire template
  pool.withAcquire(conn2):
    echo await conn2.ping()
```
