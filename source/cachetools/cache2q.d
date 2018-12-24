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

        CompressedList!(ListElement, Allocator)     _A1InList;
        CompressedList!(ListElement, Allocator)     _A1OutList;
        DList!(ListElement, Allocator)              _AmList;

        HashMap!(K, MapElement, Allocator)          _A1InMap;
        HashMap!(K, MapElement, Allocator)          _A1OutMap;
        HashMap!(K, MainMapElement, Allocator)      _AmMap;

    }

    final auto size(uint s)
    {
        _kin =  s/6;
        _kout = s/2;
        _km = 2*s/3;
        return this;
    }

    final Nullable!V get(K k) @safe
    {
        debug(cachetools) safe_tracef("get %s", k);

        auto keyInAm = k in _AmMap;
        if ( keyInAm )
        {
            debug(cachetools) safe_tracef("%s in main cache", k);
            MainMapElement mapElement = *keyInAm;
            _AmList.move_to_head(mapElement.list_element_ptr);
            return Nullable!V(mapElement.value);
        }
        debug(cachetools) safe_tracef("%s not in main cache", k);

        auto keyInA1Out = k in _A1OutMap;
        if ( keyInA1Out )
        {
            debug(cachetools) safe_tracef("%s in A1Out cache", k);
            // move from A1Out to Am
            auto value = keyInA1Out.value;
            () @trusted
            {
                assert((*keyInA1Out.list_element_ptr).key == k);
                _A1OutList.remove(keyInA1Out.list_element_ptr);
            }();

            bool removed = _A1OutMap.remove(k);
            assert(removed);
            debug(cachetools) safe_tracef("%s removed from A1Out cache", k);

            auto mlp = _AmList.insertFront(ListElement(k));
            _AmMap.put(k, MainMapElement(value, mlp));
            debug(cachetools) safe_tracef("%s placed to Main cache", k);
            if ( _AmList.length > _km )
            {
                debug(cachetools) safe_tracef("Main cache overflowed, pop %s", _AmList.tail().key);
                _AmMap.remove(_AmList.tail().key);
                _AmList.popBack();
            }
            return Nullable!V(value);
        }
        debug(cachetools) safe_tracef("%s not in A1Out cache", k);

        auto keyInA1In = k in _A1InMap;
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
    final PutResult put(K k, V v) @safe
    out
    {
        assert(__result != PutResult(PutResultFlag.None));
    }
    do
    {
        auto keyInAm = k in _AmMap;
        if ( keyInAm )
        {
            (*keyInAm).value = v;
            debug(cachetools) safe_tracef("%s in Main cache", k);
            return PutResult(PutResultFlag.Replaced);
        }
        debug(cachetools) safe_tracef("%s not in Main cache", k);

        auto keyInA1Out = k in _A1OutMap;
        if ( keyInA1Out )
        {
            (*keyInA1Out).value = v;
            debug(cachetools) safe_tracef("%s in Out cache", k);
            return PutResult(PutResultFlag.Replaced);
        }
        debug(cachetools) safe_tracef("%s not in Out cache", k);

        auto keyInA1 = k in _A1InMap;
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
            ListElementPtrType lp = _A1InList.insertBack(ListElement(k));
            _A1InMap.put(k, MapElement(v, lp));
            if ( _A1InList.length <= _kin )
            {
                return PutResult(PutResultFlag.Inserted);
            }

            auto f = _A1InList.front;
            auto toOutK = f.key;
            auto toOutV = (*(toOutK in _A1InMap)).value;
            debug(cachetools) safe_tracef("pop %s from A1InFifo", toOutK);
            _A1InList.popFront();
            bool removed = _A1InMap.remove(toOutK);
            assert(removed);

            assert(_A1InList.length == _A1InMap.length);

            // and push to A1Out
            lp = _A1OutList.insertBack(ListElement(toOutK));
            _A1OutMap.put(toOutK, MapElement(toOutV, lp));
            if ( _A1OutList.length <= _kout )
            {
                return PutResult(PutResultFlag.Inserted);
            }
            //
            // A1Out overflowed - throw away head
            //
            f = _A1OutList.front;
            _A1OutList.popFront();
            debug(cachetools) safe_tracef("pop %s from A1OutFifo", f.key);
            removed = _A1OutMap.remove(f.key);
            assert(removed);
            assert(_A1OutList.length == _A1OutMap.length);
        }
        return PutResult(PutResultFlag.Inserted);
    }
}

@safe unittest
{
    import std.stdio;
    import std.datetime;
    import core.thread;
    import std.algorithm;
    import std.experimental.logger;
    globalLogLevel = LogLevel.info;
    info("Testing 2Q");
    auto cache = new Cache2Q!(int, int);
    cache.size = 9;
    cache.get(1);
    cache.put(1,1);
    cache.put(2,2);
    cache.put(3,3);
    // 1,2,3 in In
    cache.put(4,4);
    cache.put(5,5);
    cache.put(6,6);
    // 1,2,3 in Out, 4,5,6 in In
    //writefln("In:  %s", cache._A1InMap.byKey);
    //writefln("Out: %s", cache._A1OutMap.byKey);
    //writefln("Am: %s", cache._AmMap.byKey);
    //assert(cache.get(6) == 6);
    //writefln("In:  %s", cache._A1InMap.byKey);
    //writefln("Out: %s", cache._A1OutMap.byKey);
    //writefln("Am: %s", cache._AmMap.byKey);
    //assert(cache.get(1) == 1);
    //writefln("In:  %s", cache._A1InMap.byKey);
    //writefln("Out: %s", cache._A1OutMap.byKey);
    //writefln("Am: %s", cache._AmMap.byKey);
    //assert(cache.get(1) == 1);
    //cache.put(1,11);
    //assert(cache.get(1) == 11);
    //cache.put(7,7);
    //writefln("In:  %s", cache._A1InMap.byKey);
    //writefln("Out: %s", cache._A1OutMap.byKey);
    //writefln("Am: %s", cache._AmMap.byKey);
    //cache.put(8,8);
    //writefln("In:  %s", cache._A1InMap.byKey);
    //writefln("Out: %s", cache._A1OutMap.byKey);
    //writefln("Am: %s", cache._AmMap.byKey);
    //assert(cache.get(2).isNull);
    globalLogLevel = LogLevel.info;
}