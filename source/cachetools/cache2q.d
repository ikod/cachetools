///
module cachetools.cache2q;

/// Implements Q2 cache
/// http://www.vldb.org/conf/1994/P439.PDF

private import std.experimental.allocator;
private import std.experimental.allocator.mallocator : Mallocator;
private import core.stdc.time;
private import std.typecons;

private import cachetools.internal;
private import cachetools.interfaces;
private import cachetools.containers.hashmap;
private import cachetools.containers.lists;

/* Pseudocode from the paper
// If there is space, we give it to X.
// If there is no space, we free a page slot to
// make room for page X.
reclaimfor(page X)
    begin
        if there are free page slots then
            put X into a free page slot
        else if( |Alin| > Kin)
            page out the tail of Alin, call it Y
            add identifier of Y to the head of Alout
            if(]Alout] >Kout)
                remove identifier of Z from
                the tail of Alout
            end if
            put X into the reclaimed page slot
        else
            page out the tail of Am, call it Y
            // do not put it on Alout; it hasn’t been
            // accessed for a while
            put X into the reclaimed page slot
        end if
end

On accessing a page X :
begin
    if X is in Am then
        move X to the head of Am
    else if (X is in Alout) then
        reclaimfor(Х)
        add X to the head of Am
    else if (X is in Alin) // do nothing
    else // X is in no queue
        reclaimfor(X)
        add X to the head of Alin
    end if
end 
*/
/**
    2Q cache is variant of multi-level LRU cache. Original paper http://www.vldb.org/conf/1994/P439.PDF
    It is adaptive, scan-resistant and can give more hits than plain LRU.
    $(P This cache consists from three parts (In, Out and Main) where 'In' receive all new elements, 'Out' receives all
    overflows from 'In', and 'Main' is LRU cache which hold all long-lived data.)
**/
class Cache2Q(K, V, Allocator=Mallocator)
{
    private
    {
        struct ListElement {
            StoredType!K        key;    // we keep key here so we can remove element from map when we evict with LRU or TTL)
        }
        alias ListType = CompressedList!(ListElement, Allocator);
        alias ListElementPtrType = ListType.NodePointer;
        alias DListType = DList!(ListElement, Allocator);
        alias DListElementPtrType = DListType.Node!ListElement*;

        struct MapElement
        {
            StoredType!V        value;
            ListElementPtrType  list_element_ptr;
            time_t              expired_at;
        }
        struct MainMapElement
        {
            StoredType!V         value;
            DListElementPtrType  list_element_ptr;
            time_t              expired_at;
        }

        int _kin, _kout, _km;

        CompressedList!(ListElement, Allocator)     _InList;
        CompressedList!(ListElement, Allocator)     _OutList;
        DList!(ListElement, Allocator)              _MainList;

        HashMap!(K, MapElement, Allocator)          _InMap;
        HashMap!(K, MapElement, Allocator)          _OutMap;
        HashMap!(K, MainMapElement, Allocator)      _MainMap;

        time_t                                      _ttl; // global ttl (if > 0)
    }
    final this() @safe {
        _InMap.grow_factor(4);
        _OutMap.grow_factor(4);
        _MainMap.grow_factor(4);
    }
    ///
    /// Set total cache size. 'In' and 'Out' gets 1/6 of total size, Main gets 2/3 of size.
    ///
    final auto size(uint s)
    {
        _kin =  1*s/6;
        _kout = 1*s/6;
        _km =   4*s/6;
        return this;
    }
    ///
    /// Set In queue size
    ///
    final auto sizeIn(uint s)
    {
        _kin =  s;
        return this;
    }

    ///
    /// Set Out queue size
    ///
    final auto sizeOut(uint s)
    {
        _kout =  s;
        return this;
    }

    ///
    /// Set Main queue size
    ///
    final auto sizeMain(uint s)
    {
        _km =  s;
        return this;
    }

    ///
    /// Number of elements in cache.
    ///
    final int length() @safe
    {
        return _InMap.length + _OutMap.length + _MainMap.length;
    }
    ///
    /// Drop all elements from cache.
    ///
    final void clear() @safe
    {
        _InList.clear();
        _OutList.clear();
        _MainList.clear();
        _InMap.clear();
        _OutMap.clear();
        _MainMap.clear();
    }
    ///
    /// Set default ttl (seconds)
    ///
    final void ttl(time_t v) @safe 
    {
        _ttl = v;
    }
    ///
    /// Get element from cache.
    ///
    final Nullable!V get(K k) @safe
    {
        debug(cachetools) safe_tracef("get %s", k);

        MainMapElement* keyInAm = k in _MainMap;
        if ( keyInAm )
        {
            debug(cachetools) safe_tracef("%s in main cache: %s", k, *keyInAm);
            auto mapElement = *keyInAm;
            if ( keyInAm.expired_at > 0 && keyInAm.expired_at <= time(null) ) 
            {
                // expired
                _MainList.remove(keyInAm.list_element_ptr);
                _MainMap.remove(k);
                //
                return Nullable!V();
            }
            _MainList.move_to_head(mapElement.list_element_ptr);
            return Nullable!V(mapElement.value);
        }
        debug(cachetools) safe_tracef("%s not in main cache", k);

        auto keyInOut = k in _OutMap;
        if ( keyInOut )
        {
            debug(cachetools) safe_tracef("%s in A1Out cache: %s", k, *keyInOut);
            if (keyInOut.expired_at > 0 && keyInOut.expired_at <= time(null))
            {
                // expired
                () @trusted {
                    _OutList.remove(keyInOut.list_element_ptr);
                }();
                _OutMap.remove(k);
                //
                return Nullable!V();
            }
            // move from Out to Main
            auto value = keyInOut.value;
            auto expired_at = keyInOut.expired_at;

            () @trusted
            {
                assert((*keyInOut.list_element_ptr).key == k);
                _OutList.remove(keyInOut.list_element_ptr);
            }();

            bool removed = _OutMap.remove(k);
            assert(removed);
            debug(cachetools) safe_tracef("%s removed from A1Out cache", k);

            auto mlp = _MainList.insertFront(ListElement(k));
            _MainMap.put(k, MainMapElement(value, mlp, expired_at));
            debug(cachetools) safe_tracef("%s placed to Main cache", k);
            if ( _MainList.length > _km )
            {
                debug(cachetools) safe_tracef("Main cache overflowed, pop %s", _MainList.tail().key);
                _MainMap.remove(_MainList.tail().key);
                _MainList.popBack();
            }
            return Nullable!V(value);
        }
        debug(cachetools) safe_tracef("%s not in A1Out cache", k);

        auto keyInIn = k in _InMap;
        if ( keyInIn )
        {
            debug(cachetools) safe_tracef("%s in A1In cache", k);
            if (keyInIn.expired_at > 0 && keyInIn.expired_at <= time(null))
            {
                // expired
                () @trusted {
                    _InList.remove(keyInIn.list_element_ptr);
                }();
                _InMap.remove(k);
                //
                return Nullable!V();
            }
            MapElement mapElement = *keyInIn;
            // just return value
            return Nullable!V(mapElement.value);
        }
        debug(cachetools) safe_tracef("%s not in A1In cache", k);

        return Nullable!V();
    }

    ///
    /// Put element to cache.
    ///
    final PutResult put(K k, V v, TTL ttl = TTL()) @safe
    out
    {
        assert(__result != PutResult(PutResultFlag.None));
    }
    do
    {
        time_t exp_time;
        if ( _ttl > 0 && ttl.useDefault  )
        {
            exp_time = time(null) + _ttl;
        }
        if ( ttl.value > 0 )
        {
            exp_time = time(null) + ttl.value;
        }
        auto keyInMain = k in _MainMap;
        if ( keyInMain )
        {
            keyInMain.value = v;
            keyInMain.expired_at = exp_time;
            debug(cachetools) safe_tracef("%s in Main cache", k);
            return PutResult(PutResultFlag.Replaced);
        }
        debug(cachetools) safe_tracef("%s not in Main cache", k);

        auto keyInOut = k in _OutMap;
        if ( keyInOut )
        {
            keyInOut.value = v;
            keyInOut.expired_at = exp_time;
            debug(cachetools) safe_tracef("%s in Out cache", k);
            return PutResult(PutResultFlag.Replaced);
        }
        debug(cachetools) safe_tracef("%s not in Out cache", k);

        auto keyInIn = k in _InMap;
        if ( keyInIn )
        {
            keyInIn.value = v;
            keyInIn.expired_at = exp_time;
            debug(cachetools) safe_tracef("%s in In cache", k);
            return PutResult(PutResultFlag.Replaced);
        }
        else
        {
            debug(cachetools) safe_tracef("insert %s in A1InFifo", k);
            auto lp = _InList.insertBack(ListElement(k));
            _InMap.put(k, MapElement(v, lp, exp_time));
            if ( _InList.length <= _kin )
            {
                return PutResult(PutResultFlag.Inserted);
            }

            debug(cachetools) safe_tracef("pop %s from InLlist", _InList.front.key);

            auto toOutK = _InList.front.key;
            _InList.popFront();

            auto in_ptr = toOutK in _InMap;

            auto toOutV = in_ptr.value;
            auto toOutE = in_ptr.expired_at;
            bool removed = _InMap.remove(toOutK);

            assert(removed);
            assert(_InList.length == _InMap.length);

            if ( toOutE > 0 && toOutE <= time(null) )
            {
                // expired, we done
                return PutResult(PutResultFlag.Inserted|PutResultFlag.Evicted);
            }

            // and push to Out
            lp = _OutList.insertBack(ListElement(toOutK));
            _OutMap.put(toOutK, MapElement(toOutV, lp, toOutE));
            if ( _OutList.length <= _kout )
            {
                return PutResult(PutResultFlag.Inserted|PutResultFlag.Evicted);
            }
            //
            // Out overflowed - throw away head
            //
            debug(cachetools) safe_tracef("pop %s from A1OutFifo", _OutList.front.key);

            removed = _OutMap.remove(_OutList.front.key);
            _OutList.popFront();

            assert(removed);
            assert(_OutList.length == _OutMap.length);

            return PutResult(PutResultFlag.Inserted|PutResultFlag.Evicted);
        }
    }
    ///
    /// Remove element from cache.
    ///
    final bool remove(K k) @safe
    {
        debug(cachetools) safe_tracef("remove from 2qcache key %s", k);
        auto inIn = k in _InMap;
        if ( inIn )
        {
            auto lp = inIn.list_element_ptr;
            () @trusted
            {
                _InList.remove(lp);
            }();
            _InMap.remove(k);
            return true;
        }
        auto inOut = k in _OutMap;
        if ( inOut )
        {
            auto lp = inOut.list_element_ptr;
            () @trusted
            {
                _OutList.remove(lp);
            }();
            _OutMap.remove(k);
            return true;
        }
        auto inMain = k in _MainMap;
        if ( inMain )
        {
            auto lp = inMain.list_element_ptr;
            _MainList.remove(lp);
            _MainMap.remove(k);
            return true;
        }
        return false;
    }
}

@safe unittest
{
    import std.stdio, std.format;
    import std.datetime;
    import core.thread;
    import std.algorithm;
    import std.experimental.logger;
    globalLogLevel = LogLevel.info;
    info("Testing 2Q");
    auto cache = new Cache2Q!(int, int);
    cache.size = 12;
    foreach(i;0..11)
    {
        cache.put(i,i);
        cache.get(i-3);
    }
    cache.put(11,11);
    // In:   [11, 10]
    // Out:  [8, 9]
    // Main: [0, 6, 7, 2, 3, 1, 5, 4]
    assert(cache._InMap.length == 2);
    assert(cache._OutMap.length == 2);
    assert(cache._MainMap.length == 8);
    assert(cache.length==12, "expected 12, got %d".format(cache.length));
    foreach(i;0..12)
    {
        assert(cache.get(i) == i, "missed %s".format(i));
    }
    cache.clear();
    assert(cache.length==0);
    foreach(i;0..11)
    {
        cache.put(i,i);
        cache.get(i-3);
    }
    cache.put(11,11);
    foreach(i;0..12)
    {
        assert(cache.remove(i), "failed to remove %s".format(i));
    }
    assert(cache.length==0);
    foreach(i;0..11)
    {
        cache.put(i,i);
        cache.get(i-3);
    }
    cache.put(11,11);
    // In:   [11, 10]
    // Out:  [8, 9]
    // Main: [0, 6, 7, 2, 3, 1, 5, 4]
    cache.put(11,22);
    cache.put(8, 88);
    cache.put(5,55);
    assert(cache.get(5) == 55);
    assert(cache.get(11) == 22);
    assert(cache.length==12, "expected 12, got %d".format(cache.length));
    assert(cache.get(8) == 88); // 8 moved from Out to Main
    assert(cache.length==11, "expected 11, got %d".format(cache.length));
    cache.put(12,12);   // in iverflowed, out filled
    cache.put(13, 13);  // in overflowed, out overflowed to main
    assert(cache.length==12, "expected 12, got %d".format(cache.length));
    globalLogLevel = LogLevel.info;
}

unittest
{
    // testing ttl
    import std.stdio, std.format;
    import std.datetime;
    import core.thread;
    import std.experimental.logger;

    globalLogLevel = LogLevel.info;
    auto cache = new Cache2Q!(int, int);
    cache.sizeIn = 2;
    cache.sizeOut = 2;
    cache.sizeMain = 4;
    cache.put(1, 1, TTL(1));
    cache.put(2, 2, TTL(1));
    // in: 1, 2
    cache.put(3,3);
    cache.put(4,4);
    // in: 3, 4
    // out 1, 2
    cache.get(1);
    // in: 3, 4
    // out 2
    // main: 1
    cache.put(5,5, TTL(1));
    // In: 4(-), 5(1)   //
    // Out: 2(1), 3(-)  // TTL in parens
    // Main: 1(1)       //
    assert(4 in cache._InMap && 5 in cache._InMap);
    assert(2 in cache._OutMap && 3 in cache._OutMap);
    assert(1 in cache._MainMap);
    Thread.sleep(1500.msecs);
    assert(cache.get(1).isNull);
    assert(cache.get(2).isNull);
    assert(cache.get(5).isNull);
    assert(cache.get(3) == 3);
    assert(cache.get(4) == 4);
    cache.clear;
    cache.ttl = 1;
    cache.put(1, 1);            // default TTL - this must not survive 1.5s sleep
    cache.put(2, 2, ~TTL());    // no TTL, ignore default - this must survive any time 
    cache.put(3, 3, TTL(2));    // set TTL for this item - this must not survive 2.5s
    Thread.sleep(1000.msecs);
    assert(cache.get(1).isNull);
    assert(cache.get(2) == 2);
    assert(cache.get(3) == 3);
    Thread.sleep(1000.msecs);
    assert(cache.get(2) == 2);
    assert(cache.get(3).isNull);
}

///
///
///
@safe unittest
{
    auto cache = new Cache2Q!(int, string);
    cache.size = 1024;
    cache.sizeIn = 10;
    cache.sizeOut = 55;
    cache.sizeMain = 600;
    cache.put(1, "one");
    assert(cache.get(1) == "one");
    assert(cache.get(2).isNull);
    assert(cache.length == 1);
    cache.clear;
}
