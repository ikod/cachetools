module cachetools.cache;

import std.typecons;
import std.exception;
import std.experimental.logger;
import core.stdc.time;
import std.datetime;

private import std.experimental.allocator;
private import std.experimental.allocator.mallocator : Mallocator;

private import cachetools.internal;
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
            StoredType!V        value;  // value
            ushort              hits;   // accesses
            time_t              ts;     // creation
            ListElementPtr      list_element_ptr;
        }

        alias allocator         = Allocator.instance;
        alias ListElementPtr    = __elements.Node*;

        MultiDList!(ListElement, 2, Allocator)  __elements;
        HashMap!(K, MapElement, Allocator)      __map;
        SList!(CacheEvent!(K,V), Allocator)     __events;

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
            // remove expired entry
            if ( __reportCacheEvents )
            {
                // store in event list
                CacheEvent!(K,V) cache_event = {EventType.Expired, k, store_ptr.value};
                __events.insertBack(cache_event);
            }
            // and remove from storage and list
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
                if ( __reportCacheEvents )
                {
                    auto value_ptr = e.key in __map;
                    CacheEvent!(K,V) cache_event = {EventType.Evicted, e.key, value_ptr.value};
                    __events.insertBack(cache_event);
                }
                __map.remove(e.key);
                __elements.remove(e);
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
            if ( __reportCacheEvents )
            {
                auto v_ptr = e.key in __map;
                CacheEvent!(K,V) cache_event = {EventType.Updated, e.key, v_ptr.value};
                __events.insertBack(cache_event);
            }
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
        if ( __reportCacheEvents )
        {
            auto v_ptr = e.key in __map;
            CacheEvent!(K,V) cache_event = {EventType.Removed, e.key, v_ptr.value};
            __events.insertBack(cache_event);
        }
        __map.remove(e.key);
        __elements.remove(e);
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

    public auto size(size_t s) pure nothrow @safe @nogc
    {
        __size = s;
        return this;
    }

    public size_t size() pure nothrow const @safe @nogc
    {
        return __size;
    }

    public auto ttl(uint d) pure nothrow @safe @nogc
    {
        __ttl = d;
        return this;
    }

    public uint ttl() pure nothrow const @safe @nogc
    {
        return __ttl;
    }
    public auto enableCacheEvents() pure nothrow @safe @nogc
    {
        __reportCacheEvents = true;
        return this;
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
    lru.size(4).ttl(1).enableCacheEvents();

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
    foreach(e; lru.__events)
    {
        writeln(*e);
    }
}


@safe unittest
{
    struct S {}
    CacheLRU!(immutable S, string) cache = new CacheLRU!(immutable S, string);
}

@safe unittest
{
    struct S
    {
        int s;
    }
    auto  cache = new CacheLRU!(string, immutable S);
    immutable S s1 = immutable S(1);
    cache.put("one", s1);
    auto s11 = cache.get("one");
    assert(s11 == s1);
    immutable S s12 = immutable S(12);
    cache.put("one", s12);
    auto s121 = cache.get("one");
    assert(s121 == s12);
}