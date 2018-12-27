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
        }
        struct MainMapElement
        {
            StoredType!V         value;
            DListElementPtrType  list_element_ptr;
        }

        int _kin, _kout, _km;

        CompressedList!(ListElement, Allocator)     _InList;
        CompressedList!(ListElement, Allocator)     _OutList;
        DList!(ListElement, Allocator)              _MainList;

        HashMap!(K, MapElement, Allocator)          _InMap;
        HashMap!(K, MapElement, Allocator)          _OutMap;
        HashMap!(K, MainMapElement, Allocator)      _MainMap;

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
    /// Number of elements in cache.
    ///
    final auto length() @safe
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
    /// Get element from cache.
    ///
    final Nullable!V get(K k) @safe
    {
        debug(cachetools) safe_tracef("get %s", k);

        auto keyInAm = k in _MainMap;
        if ( keyInAm )
        {
            debug(cachetools) safe_tracef("%s in main cache", k);
            MainMapElement mapElement = *keyInAm;
            _MainList.move_to_head(mapElement.list_element_ptr);
            return Nullable!V(mapElement.value);
        }
        debug(cachetools) safe_tracef("%s not in main cache", k);

        auto keyInA1Out = k in _OutMap;
        if ( keyInA1Out )
        {
            debug(cachetools) safe_tracef("%s in A1Out cache", k);
            // move from A1Out to Am
            auto value = keyInA1Out.value;
            () @trusted
            {
                assert((*keyInA1Out.list_element_ptr).key == k);
                _OutList.remove(keyInA1Out.list_element_ptr);
            }();

            bool removed = _OutMap.remove(k);
            assert(removed);
            debug(cachetools) safe_tracef("%s removed from A1Out cache", k);

            auto mlp = _MainList.insertFront(ListElement(k));
            _MainMap.put(k, MainMapElement(value, mlp));
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

        auto keyInA1In = k in _InMap;
        if ( keyInA1In )
        {
            debug(cachetools) safe_tracef("%s in A1In cache", k);
            MapElement mapElement = *keyInA1In;
            // just return value
            return Nullable!V(mapElement.value);
        }
        debug(cachetools) safe_tracef("%s not in A1In cache", k);

        return Nullable!V();
    }
    ///
    /// Put element to cache.
    ///
    final PutResult put(K k, V v) @safe
    out
    {
        assert(__result != PutResult(PutResultFlag.None));
    }
    do
    {
        auto keyInAm = k in _MainMap;
        if ( keyInAm )
        {
            (*keyInAm).value = v;
            debug(cachetools) safe_tracef("%s in Main cache", k);
            return PutResult(PutResultFlag.Replaced);
        }
        debug(cachetools) safe_tracef("%s not in Main cache", k);

        auto keyInA1Out = k in _OutMap;
        if ( keyInA1Out )
        {
            (*keyInA1Out).value = v;
            debug(cachetools) safe_tracef("%s in Out cache", k);
            return PutResult(PutResultFlag.Replaced);
        }
        debug(cachetools) safe_tracef("%s not in Out cache", k);

        auto keyInA1 = k in _InMap;
        if ( keyInA1 )
        {
            (*keyInA1).value = v;
            debug(cachetools) safe_tracef("%s in In cache", k);
            return PutResult(PutResultFlag.Replaced);
        }
        else
        {
            // XXX do not check InMap twice: 1. k in map, 2. put(k)
            debug(cachetools) safe_tracef("insert %s in A1InFifo", k);
            ListElementPtrType lp = _InList.insertBack(ListElement(k));
            _InMap.put(k, MapElement(v, lp));
            if ( _InList.length <= _kin )
            {
                return PutResult(PutResultFlag.Inserted);
            }

            auto f = _InList.front;
            auto toOutK = f.key;
            auto toOutV = (*(toOutK in _InMap)).value;
            debug(cachetools) safe_tracef("pop %s from A1InFifo", toOutK);
            _InList.popFront();
            bool removed = _InMap.remove(toOutK);
            assert(removed);

            assert(_InList.length == _InMap.length);

            // and push to A1Out
            lp = _OutList.insertBack(ListElement(toOutK));
            _OutMap.put(toOutK, MapElement(toOutV, lp));
            if ( _OutList.length <= _kout )
            {
                return PutResult(PutResultFlag.Inserted);
            }
            //
            // A1Out overflowed - throw away head
            //
            f = _OutList.front;
            _OutList.popFront();
            debug(cachetools) safe_tracef("pop %s from A1OutFifo", f.key);
            removed = _OutMap.remove(f.key);
            assert(removed);
            assert(_OutList.length == _OutMap.length);
        }
        return PutResult(PutResultFlag.Inserted);
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
///
///
///
@safe unittest
{
    auto cache = new Cache2Q!(int, string);
    cache.size = 1024;
    cache.put(1, "one");
    assert(cache.get(1) == "one");
    assert(cache.get(2).isNull);
    assert(cache.length == 1);
}
