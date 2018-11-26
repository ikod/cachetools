# cachetools #

This package contains some cache implementations (for example LRU cache) and underlying data structures.

All code is `@safe`. It is also `@nogc` if key and value types support @nogc for some important operations.
cachetools use std.experimantal.allocator with configurable allocator when it need allcation.

### LRU cache ###

LRU cache keep limited number of items in memory. When adding new item to already full cache we have to evict some items.
Eviction candidates are selected first from expired items (using per-cache configurable TTL) or from oldest accessed items.

## Code examples ##

```d
    auto lru = new CacheLRU!(int, string);
    lru.size = 2048; // keep 2048 elements in cache
    lru.ttl = 60;    // set 60 seconds TTL for items in cache
    
    lru.put(1, "one");
    auto v = lru.get(1);
    assert(v == "one"); // 1 is in cache
    v = lru.get(2);
    assert(v.isNull);   // no such item in cache

```

Default values for TTL is 0 which means - no TTL. Default value for size is 1024;

### Class instance as key ###

To use class as key with this code, you have to define toHash and opEquals as safe or trusted (optionally as nogc if
you need it):

```d
    import cachetools.hash: hash_function;
    class C
    {
        int s;
        this(int v)
        {
            s = v;
        }
        override hash_t toHash() const
        {
            return hash_function(s);
        }
        bool opEquals(const C other) pure const @safe
        {
            return s == other.s;
        }
    }
    CacheLRU!(immutable C, string) cache = new CacheLRU!(immutable C, string);
    immutable C s1 = new immutable C(1);
    cache.put(s1, "one");
    auto s11 = cache.get(s1);
    assert(s11 == "one");

```

### Cache events ###

Sometimes you have to know if items are purged from cache or modified. You can configure cache to report such events.
*Important warning* - if you enable cache events and do not check it after cache operations, then list of stored events will
grow without bounds. Code sample:
```d

    auto lru = new CacheLRU!(int, string);
    lru.enableCacheEvents();
    lru.put(1, "one");
    lru.put(1, "next one");
    assert(lru.get(1) == "next one");
    auto events = lru.cacheEvents();
    writeln(events);

```
output:
```
[CacheEvent!(int, string)(Updated, 1, "one")]
```
Each `CacheEvent` have `key` and `val` members and name of the event(Removed, Expired, Changed, Evicted).

## Hash Table ##

Some parts of this package are based on internal hash table which can be used independently. It is open-addressing
hash table with keys and values stored inline in the buckets array to avoid unnecessary allocations and better use 
of CPU cache for small key/value types.

Hash Table supports immutable keys and values. Due to language limitations you can't use structs with immutable/const
members.

All hash table code is `@safe` and require `@safe` or `@trusted` user supplied functions such as `toHash` or `opEquals`.
It is also `@nogc` if `toHash` and `opEquals` are `@nogc`.

