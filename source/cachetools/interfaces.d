module cachetools.interfaces;

import std.typecons;
import std.datetime;

//
// cache have aspects:
// 1. storage: hashmap and some kind of order of elements
// 2. stream of evicted elements, which user may want to handle(slose files, sockets, etc)
// 3. eviction policy (condition to start/stop evinction)
//

// implements storage aspect of cache
interface Cache(K, V) {

    // get value from cache
    Nullable!V get(K) @safe;

    // put value to cache
    void put(K, V) @safe;

    // remove key
    bool  remove(K) @safe;
    
    // clear entire cache
    void  clear() @safe;
    
    // # of elements
    ulong length() const @safe @nogc;

}

template RemovedEntry(K, V) {
    alias RemovedEntry = Tuple!(K, "key", V, "value");
}

interface RemovedEntryListener(K, V) {
    void add(K, V) @nogc @safe;
    RemovedEntry!(K,V) get() @nogc @safe;
    bool empty() const @nogc @safe;
}

