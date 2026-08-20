# Cache in front of a slow origin (example assignment)

The origin takes 200ms and cannot take much load. Your cache sits in front of
it. Keys go stale after a while, and the process has to run for months.

Your problem is `cache.ts`, and one method in it.

## What to do

1. **`get(key)`** — the value, from the cache when it is there and still good.
2. The cache is constructed with a `capacity` and a `ttlMs`. Both should mean
   something.

## What you are marked on

Whether you can defend it in a viva. The examiner reads your file before it
asks anything, and can run your cache.
