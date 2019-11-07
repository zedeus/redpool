# redpool

Simple Redis connection pool.

The `timeout` argument allows connections to be reused after a given time, in
case they don't get released properly. The `maxConn` argument sets a soft
limit, which destroys connection objects when released if the limit has been
reached. The `withAcquire` template can be used to automatically acquire and
release a connection, but note the `acquire` call is `waitFor`'d since `async`
isn't yet allowed inside templates and macros.

# Usage

```nim
import asyncdispatch, redis, redpool

proc main {.async.} =
  let pool = await newRedisPool(5, timeout=4, maxConn=2)
  let conn = await pool.acquire()
  echo await conn.ping()
  pool.release(conn)

  pool.withAcquire(conn2):
    echo await conn2.ping()
```
