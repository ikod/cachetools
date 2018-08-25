module cachetools.interfaces;

import std.typecons;
import std.datetime;

import optional;

//
// cache have aspects:
// 1. storage: hashmap and some kind of order of elements
// 2. stream of evicted elements, which user may want to handle(slose files, sockets, etc)
// 3. eviction policy (condition to start/stop evinction)
//

// implements storage aspect of cache
interface CachePolicy(K, V) {

    // get value from cache
    Optional!V get(K) @safe @nogc;

    // put value to cache
    void put(K, V) @safe @nogc;

    // remove key
    bool  remove(K) @safe @nogc;
    
    // clear entire cache
    void  clear() @safe @nogc;
    
    // # of elements
    ulong length() const @safe @nogc;

}

template RemovedEntry(K, V) {
    alias RemovedEntry = Tuple!(K, "key", V, "value");
}

class RemovedEntryListener(K, V) {
    void add(K, V) @nogc @safe {}
    RemovedEntry!(K,V) get() @nogc @safe {return RemovedEntry!(K,V).init;}
    bool empty() const @nogc @safe {return false;}
}

struct CacheElement(V) {
    package {
        V       _value;
        size_t  _size;
        ulong   _hits;
        //SysTime _created;
        //SysTime _updated;
        //SysTime _accessed;
    }
    this(V value) {
        _value = value;
    }
    @property
        V value() const {
            return _value;
        }
}