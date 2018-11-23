module cachetools.cache;

import std.typecons;
import std.exception;
import std.experimental.logger;
import core.stdc.time;
import std.datetime;

private import std.experimental.allocator;
private import std.experimental.allocator.mallocator : Mallocator;

private import cachetools.interfaces;
private import cachetools.containers.hashmap;
private import cachetools.containers.lists;


///
/// CacheLRU contains maximum `size` items
/// Eviction policy:
/// 1. evict TTL-ed entry (if TTL)
/// 2. if oldest entry not expired - evict oldes accessed (LRU)
///
/// User informed about evicted entries via cache event listener.
///

class CacheLRU(K, V, Allocator = Mallocator) : Cache!(K, V)
{
    ///
    /// Implemented as HashMap and multi-dlist.
    ///
    /// HashMap (by key) keep 
    ///  1. cached value
    ///  2. pointer to dlist element.
    ///  3. creation time (to check expiration and purge expired entry on get())
    ///  4. hits counter
    ///
    /// dlist keep key, cteation timestamp (to check expiration)
    ///  1. key, so that we can remove entries from hashmap for lists heads (AccessIndex and TimeIndex)
    ///  2. creation time, so that we can check expiration for 'TimeIndex'
    ///
    /// Each element in dlist have two sets of double-links - first set create order by access time, second set
    ///  for creation time.
    ///
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

        MultiDList!(ListElement, 2, Allocator)  __elements;
        HashMap!(K, MapElement, Allocator)      __map;
        SList!(CacheEvent!(K,V))                __eventList;

        // configuration
        size_t                          __size = 1024;
        uint                            __ttl;
        bool                            __reportCacheEvents;
    }

    public Nullable!V get(K k) @safe
    {
        debug(cachetools) tracef("get %s", k);
        auto store_ptr = k in __map;
        if ( !store_ptr )
        {
            return Nullable!V();
        }
        if  (__ttl > 0 && time(null) - store_ptr.ts >= __ttl )
        {
            // deactivate this entry
            // XXX send REMOVE to event listener
            __map.remove(k);
            __elements.remove(store_ptr.list_element_ptr);
            return Nullable!V();
        }
        store_ptr.hits++;
        auto order_p = store_ptr.list_element_ptr;
        __elements.move_to_tail(order_p, AccessIndex);
        return Nullable!V(store_ptr.value);
    }

    public PutResult put(K k, V v) @safe
    out
    {
        assert(__result != PutResult(PutResultFlag.None));
    }
    do
    {
        time_t ts = time(null);
        PutResult result;
        auto store_ptr = k in __map;
        if ( !store_ptr ) // insert element
        {
            result = PutResultFlag.Inserted;
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
                    // purge lru element
                    e = __elements.head(AccessIndex);
                    debug(cachetools) tracef("purging lru %s", *e);
                }
                assert(e !is null);
                __map.remove(e.key);
                __elements.remove(e);
                // XXX send PURGED event to event listener
                result |= PutResultFlag.Evicted;
            }
            auto order_node = __elements.insert_last(ListElement(k, ts));
            MapElement e = {value:v, ts: ts, list_element_ptr: order_node};
            __map.put(k, e);
        }
        else // update element
        {
            result = PutResultFlag.Replaced;
            debug(cachetools) tracef("update %s", *store_ptr);
            ListElementPtr e = store_ptr.list_element_ptr;
            e.ts = ts;
            __elements.move_to_tail(e, TimeIndex);

            // XXX send UPDATE event to event listener
            store_ptr.value = v;
            store_ptr.ts = ts;
        }
        return result;
    }

    public bool remove(K k) @safe
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
        // XXX send REMOVE event to event listener
        return true;
    }

    public void clear() @safe
    {
        __map.clear();
        __elements.clear();
    }

    public size_t length() pure nothrow const @safe @nogc
    {
        return __elements.length;
    }

    public void size(size_t s) pure nothrow @safe @nogc
    {
        __size = s;
    }

    public size_t size() pure nothrow const @safe @nogc
    {
        return __size;
    }

    public void ttl(uint d) pure nothrow @safe @nogc
    {
        __ttl = d;
    }

    public uint ttl() pure nothrow const @safe @nogc
    {
        return __ttl;
    }
}

@safe unittest
{
    import std.stdio;
    import std.datetime;
    import core.thread;
    globalLogLevel = LogLevel.info;
    PutResult r;

    auto lru = new CacheLRU!(int, string);
    lru.size = 4;
    lru.ttl = 1;
    assert(lru.length == 0);
    r = lru.put(1, "one"); assert(r == PutResult(PutResultFlag.Inserted));
    r = lru.put(2, "two"); assert(r == PutResult(PutResultFlag.Inserted));
    auto v = lru.get(1);
    assert(v=="one");
    r = lru.put(3, "three"); assert(r & PutResultFlag.Inserted);
    r = lru.put(4, "four"); assert(r & PutResultFlag.Inserted);
    assert(lru.length == 4);
    // next put should purge...
    r = lru.put(5, "five"); assert(r == PutResult(PutResultFlag.Evicted, PutResultFlag.Inserted));
    () @trusted {Thread.sleep(2.seconds);}();
    v = lru.get(1); // it must be expired by ttl
    assert(v.isNull);
    assert(lru.length == 3);
    r = lru.put(6, "six"); assert(r == PutResult(PutResultFlag.Inserted));
    assert(lru.length == 4);
    r = lru.put(7, "seven"); assert(r == PutResult(PutResultFlag.Evicted, PutResultFlag.Inserted));
    assert(lru.length == 4);
    lru.put(7, "7");
    assert(lru.length == 4);
    assert(lru.get(7) == "7");
    lru.clear();
    assert(lru.length == 0);
    assert(lru.get(7).isNull);
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

@safe unittest
{
    struct S {}
    CacheLRU!(immutable S, string)  cache;
}

@safe unittest
{
    //struct S {}
    //CacheLRU!(string, immutable S)  cache;
}