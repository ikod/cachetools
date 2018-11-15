module cachetools.cache;

import cachetools.interfaces;
import cachetools.containers.hashmap;
import cachetools.containers.lists;

import std.typecons;
import std.exception;
import std.experimental.logger;
import core.stdc.time;
import std.datetime;

import optional;

///
/// CacheFIFO contains exactly `size` items
/// Replacement policy - evict oldest entry
///

private import std.format;
private import stdx.allocator;
private import stdx.allocator.mallocator : Mallocator;

class CacheLRU(K, V, Allocator = Mallocator) : Cache!(K, V)
{
    private
    {
        enum size_t AccessIndex = 0;
        enum size_t TimeIndex = 1;
        struct ListElement {
            K                   key;
            time_t              ts;     // creation
        }
        struct MapElement {
            V                   value;  // value
            ushort              hits;   // accesses
            time_t              ts;     // creation
            ListElementPtr      list_element_ptr;
        }

        alias allocator         = Allocator.instance;
        alias ListElementPtr    = __elements.Node*;

        MultiDList!(ListElement, 2)     __elements;
        HashMap!(K, MapElement)         __map;

        // configuration
        size_t                          __size = 1024;
        uint                            __ttl;
    }

    Nullable!V get(K k) @safe @nogc
    {
        debug(cachetools) tracef("get %s", k);
        auto store_p = k in __map;
        if ( !store_p )
        {
            return Nullable!V();
        }
        if  (__ttl > 0 && time(null) - store_p.ts >= __ttl )
        {
            // deactivate this entry
            // XXX send REMOVE to event listener
            __map.remove(k);
            __elements.remove(store_p.list_element_ptr);
            return Nullable!V();
        }
        store_p.hits++;
        auto order_p = store_p.list_element_ptr;
        __elements.move_to_tail(order_p, AccessIndex);
        return Nullable!V(store_p.value);
    }

    void put(K k, V v) @safe @nogc
    {
        time_t ts = time(null);
        auto store_p = k in __map;
        if ( !store_p ) // insert element
        {
            if (__elements.length >= __size )
            {
                ListElementPtr e;
                // we have to purge
                // 1. check if oldest element is ttled
                if ( __ttl > 0 && ts - __elements.head(TimeIndex).ts >= __ttl )
                {
                    // purge ttl-ed element
                    e = __elements.head(TimeIndex);
                    debug(cachetools) tracef("purging ttled %s", *e);
                }
                else
                {
                    // purge lru
                    e = __elements.head(AccessIndex);
                    debug(cachetools) tracef("purging lru %s", *e);
                }
                assert(e !is null);
                __map.remove(e.key);
                __elements.remove(e);
            }
            auto order_node = __elements.insert_last(ListElement(k, ts));
            MapElement e = {value:v, ts: ts, list_element_ptr: order_node};
            __map.put(k, e);
            return;
        }
        else // update element
        {
            debug(cachetools) tracef("update %s", *store_p);
            ListElementPtr e = store_p.list_element_ptr;
            e.ts = ts;
            __elements.move_to_tail(e, TimeIndex);

            // XXX send UPDATE to event listener
            store_p.value = v;
            store_p.ts = ts;
        }
    }

    bool remove(K k)
    {
        debug(cachetools) tracef("remove from cache %s", k);
        auto map_ptr = k in __map;
        if ( !map_ptr ) // do nothing
        {
            return false;
        }
        ListElementPtr e = map_ptr.list_element_ptr;
        __map.remove(e.key);
        __elements.remove(e);
        // XXX send remove to event listener
        return true;
    }

    void clear()
    {
        
    }

    ulong length() const @safe @nogc
    {
        return __elements.length;
    }

    void size(size_t s) @safe @nogc
    {
        __size = s;
    }

    size_t size() const @safe @nogc
    {
        return __size;
    }

    void ttl(uint d) @safe @nogc
    {
        __ttl = d;
    }

    uint ttl() const @safe @nogc
    {
        return __ttl;
    }
}

unittest
{
    import std.stdio;
    import std.datetime;
    import core.thread;
    globalLogLevel = LogLevel.info;

    auto lru = new CacheLRU!(int, string);
    lru.size = 4;
    lru.ttl = 1;
    assert(lru.length == 0);
    lru.put(1, "one");
    lru.put(2, "two");
    auto v = lru.get(1);
    assert(v=="one");
    lru.put(3, "three");
    lru.put(4, "four");
    assert(lru.length == 4);
    // next put should purge...
    lru.put(5, "five");
    Thread.sleep(2.seconds);
    v = lru.get(1); // it must be expired by ttl
    assert(v.isNull);
    assert(lru.length == 3);
    lru.put(6, "six");
    assert(lru.length == 4);
    lru.put(7, "seven");
    assert(lru.length == 4);
    lru.put(7, "7");
    assert(lru.length == 4);
    assert(lru.get(7) == "7");
}

class RemovedEntriesList(K, V): RemovedEntryListener!(K, V) {
    private {
        SList!(RemovedEntry!(K, V)) list;
        ulong _limit;
    }

    this(ulong limit = 32) {
            _limit = limit;
            enforce!Exception(_limit >= 1);
        }
    
        override void
    add(K k, V v) @nogc @safe
        //out { assert(list.length < _limit);}
        do  {
            debug(cachetools) tracef("insert into removed list (%d)%d", k, list.length);
            if ( list.length == _limit) {
                assert(0, "You exceeded RemovedList limit");
            }
            list.insertBack(RemovedEntry!(K, V)(k, v));
            debug(cachetools) trace("inserted");
        }

        override 
    RemovedEntry!(K, V) get() @safe @nogc
        //in { assert(!list.empty); }
        do {
            auto kv = list.front();
            list.popFront();
            return kv;
        }
    
        override bool
    empty() @nogc @safe const {
            return list.empty();
        }
}

//@safe unittest {
//    auto r = new RemovedEntriesList!(int, string)(16);
//    () @nogc {
//        assert(r.empty);
//
//        r.add(1, "one");
//        assert(!r.empty);
//        auto e = r.get();
//        assert(e.key == 1 && e.value == "one");
//        assert(r.empty);
//        foreach (i; 0..14) {
//            r.add(i, "string");
//        }
//
//        while(!r.empty) {
//            auto v = r.get();
//        }
//    }();
//}
//
//@safe unittest {
//
//    alias K = int;
//    alias V = string;
//    FIFOPolicy!(K,V) cache = new FIFOPolicy!(K, V);
//    RemovedEntryListener!(K, V) rel = new RemovedEntriesList!(K, V)();
//    cache
//        .removedEntryListener(rel)
//        .maxLength(32);
//
//    () @nogc {
//        import std.range;
//        import std.algorithm;
//
//        SList!int removed_keys;
//
//        foreach (i; 0..1000) {
//            cache.put(i, "string");
//            while(!rel.empty) {
//                auto kv = rel.get();
//                removed_keys.insertBack(kv.key);
//            }
//        }
//
//        foreach(i; iota(968)) {
//            assert(removed_keys.front == i);
//            removed_keys.popFront();
//        }
//
//    }();
//}
//
