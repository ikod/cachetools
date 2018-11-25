module cachetools.interfaces;

import std.typecons;
import std.datetime;
import std.typecons;
//
// cache have aspects:
// 1. storage: hashmap and some kind of order of elements
// 2. stream of evicted elements, which user may want to handle(slose files, sockets, etc)
// 3. eviction policy (condition to start/stop evinction)
//

enum PutResultFlag
{
    None,
    Inserted = 1 << 0,
    Replaced = 1 << 1,
    Evicted  = 1 << 2
}
alias PutResult = BitFlags!PutResultFlag;

// implements storage aspect of cache
interface Cache(K, V) {

    // get value from cache
    Nullable!V get(K) @safe;

    // put/update cache entry
    PutResult put(K, V) @safe;

    // remove key
    bool  remove(K) @safe;
    
    // clear entire cache
    void  clear() @safe;
    
    // # of elements
    size_t length() const @safe;

}

struct CacheEvent(K, V)
{
    enum Event
    {
        Removed,
        Updated
    }
    K key;
    V val;
}
