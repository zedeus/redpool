# redpool

Simple Redis connection pool.

The `timeout` argument allows connections to be reused after a given time, in
case they don't get released properly. The `maxConn` argument sets a soft
limit, which destroys connection objects when released if the limit has been
reached.

# Usage

```nim
import asyncdispatch, redis, redpool

proc main {.async.} =
  let pool = await newRedisPool(5, timeout=4, maxConn=2)
  let conn = await pool.acquire()
  echo await conn.ping()
  pool.release(conn)
```
