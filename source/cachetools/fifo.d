module cachetools.fifo;

import cachetools.interfaces;
import cachetools.containers.hashmap;
import cachetools.containers.lists;

import std.typecons;
import std.exception;

import optional;

///
/// CacheFIFO contains exactly `size` items
/// Replacement policy - evict oldest entry
///

static void log(A...)(string fmt, A args) @nogc @trusted {
    import core.stdc.stdio;
    printf(fmt.ptr, args);
}


private import std.format;
private import stdx.allocator;
private import stdx.allocator.mallocator : Mallocator;


class FIFOPolicy(K, V, Allocator = Mallocator) : CachePolicy!(K, V) {
    private {
        struct ListNode {
            K           key;
        }
        alias DListNodeType = DList!(ListNode).Node!(ListNode);
        DList!(ListNode)            nodes_list;
        HashMap!(K, DListNodeType*) nodes_map;
        HashMap!(K, V)              main_map;
        ulong                       _size=64;
        void delegate(K k, V v) @safe @nogc _onRemoval;

        alias allocator = Allocator.instance;
    }

    public void size(ulong s) @nogc @safe {
        _size = s;
    }

    public void onRemoval(void delegate(K k, V v) @safe @nogc f) {
        _onRemoval = f;
    }

    ~this() {
        clear();
    }

    invariant {
        assert(nodes_list.length  == nodes_map.length && nodes_list.length == main_map.length);
        assert(_size >= main_map.length, "expected _size>=_map.length, %s>=%s".format(_size, main_map.length));
    }

    void clear() @safe @nogc {
        // clear list and map
        while (nodes_list.length > 0) {
            auto ln = nodes_list.head;
            ListNode l = ln.v;
            K key = l.key;
            nodes_list.remove(ln);
            nodes_map.remove(key);
            main_map.remove(key);
        }
        assert(nodes_map.length == 0 && nodes_list.length == 0 && main_map.length == 0);
    }

    Optional!V get(K k) {
        return main_map.get(k);
    }

    void put(K k, V v) @safe @nogc
    do {
        debug(cachetools) log("put %d\n", k);

        auto u = main_map.put(k, v);
        //
        // u is Optional!V which is not empty if we replaced old entry
        //
        if ( !u.empty ) {
            // we replaced some node
            V old_value = u.front;
            auto np = nodes_map.get(k);
            assert(!np.empty);
            nodes_list.move_to_tail(np.front);
        }
        else
        {
            // we inserted new node
            ListNode new_node = {key: k};
            auto np = nodes_list.insert_last(new_node);
            auto i = nodes_map.put(k, np);
            assert(i.empty, "Key was not in main map, but is in the nodes map");
        }
        //
        // check if we have to purge something
        //
        if ( main_map.length > _size ) {
            debug(cachetools) log("evict, length before = %d, %d\n", main_map.length, nodes_map.length);
            // ok purge head
            auto head = nodes_list.head;
            auto eviction_key = head.v.key;
            bool removed = nodes_map.remove(eviction_key);
            assert(removed);
            removed = nodes_list.remove(head);
            assert(removed);
            removed = main_map.remove(eviction_key);
            assert(removed);
        }
    }
    ulong length() const @nogc @safe {
        return nodes_map.length();
    }
    bool remove(K k) @safe @nogc {
        import std.conv;
        debug(cachetools) log("remove %d\n", k);
        auto n = nodes_map.get(k);
        bool ok  = n.match!(
            (DListNodeType* np) => nodes_map.remove(k)
                                    && nodes_list.remove(np)
                                    && main_map.remove(k),
            () => false
        );
        return ok;
    }
}

@safe unittest {
    import std.experimental.logger;
    import std.format;

    globalLogLevel = LogLevel.trace;
    bool ok;
    FIFOPolicy!(int, string) policy = new FIFOPolicy!(int, string);

    () @nogc {
        void onRemoval(int i, string s) {
            debug(cachetools) log("onRemove %d\n", i);
        }
        policy.size(3);
//        policy.onRemoval = &onRemoval;
        policy.put(1, "one");
        assert(policy.length == 1);
        policy.put(1, "one-one");
        assert(policy.length == 1);
        policy.put(2, "two");
        assert(policy.length == 2);
        auto v = policy.get(1);
        assert(!v.empty && v.front == "one-one");
        assert(policy.length == 2);
        policy.put(3, "three");
        assert(policy.length == 3);
        policy.put(4, "four");
        assert(policy.length == 3);
        v = policy.get(1);
        assert(v.empty);
        ok = policy.remove(4);
        assert(ok);
        ok = policy.remove(5);
        assert(!ok);
    }();
    globalLogLevel = LogLevel.info;
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
    out { assert(list.length < _limit);}
    do  {
        if ( list.length == _limit) {
            assert(0, "You exceeded RemovedList limit");
        }
        list.insertBack(RemovedEntry!(K, V)(k, v));
    }

    override 
    RemovedEntry!(K, V) get() @safe @nogc
    in { assert(!list.empty); }
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

@safe unittest {
    import std.stdio;
    auto r = new RemovedEntriesList!(int, string)(16);
    assert(r.empty);

    r.add(1, "one");
    assert(!r.empty);
    auto e = r.get();
    assert(e.key == 1 && e.value == "one");
    assert(r.empty);
    foreach(i; 0..14) {
        r.add(i, "string");
    }

    while(!r.empty) {
        auto v = r.get();
        writeln(v);
    }
}
