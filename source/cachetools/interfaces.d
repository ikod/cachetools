///
module cachetools.interfaces;

import std.typecons;
import std.datetime;
import std.typecons;

private import cachetools.internal;

//
// cache have aspects:
// 1. storage: hashmap and some kind of order of elements
// 2. stream of evicted elements, which user may want to handle(slose files, sockets, etc)
// 3. eviction policy (condition to start/stop evinction)
//

///
enum PutResultFlag
{
    None,
    Inserted = 1 << 0,
    Replaced = 1 << 1,
    Evicted  = 1 << 2
}
///
alias PutResult = BitFlags!PutResultFlag;

// I failed to reach both goals: inheritance from interface and nogc/nothrow attribute neutrality
// for Cache implementations. So I droped inheritance.
//
//interface Cache(K, V) {
//
//    // get value from cache
//    Nullable!V get(K) @safe;
//
//    // put/update cache entry
//    PutResult put(K, V) @safe;
//
//    // remove key
//    bool  remove(K) @safe;
//    
//    // clear entire cache
//    void  clear() @safe;
//    
//    // # of elements
//    size_t length() const @safe;
//
//}

enum EventType
{
    Removed,
    Expired,
    Evicted,
    Updated
}

struct CacheEvent(K, V)
{
    EventType       event;
    StoredType!K    key;
    StoredType!V    val;
}

struct TTL {
    import core.stdc.time;
    //
    // Can have three values
    // 1) use default - __ttl = 0
    // 2) no ttl      - __ttl = -1
    // 3) some value  - __ttl > 0
    //
    private time_t  __ttl = 0;

    bool disabled() pure const nothrow @nogc @safe {
        return __ttl < 0;
    }
    bool useDefault() pure const nothrow @nogc @safe {
        return __ttl == 0;
    }
    time_t value() pure const nothrow @nogc @safe {
        return __ttl;
    }
    TTL opUnary(string op)() pure nothrow @safe @nogc if (op == "~")
    {
        return TTL(-1);
    }
    /**
    / Constructor
    / Parameters:
    / v - ttl value (0 - use default value or no ttl if there is no defaults)
    */
    this(int v) pure nothrow @safe @nogc {
        if ( v < 0 ) {
            __ttl = -1;
        }
        else
        {
            __ttl = v;
        }
    }
}