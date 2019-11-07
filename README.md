# redpool

Simple Redis connection pool.

# Usage

```nim
import asyncdispatch, redis, redpool

proc main {.async.} =
  let pool = await newRedisPool(5)
  let conn = await pool.acquire()
  echo await conn.ping()
  pool.release(conn)
```
