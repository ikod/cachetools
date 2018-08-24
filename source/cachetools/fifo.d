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
        alias allocator = Allocator.instance;

        struct ListNode {
            K key;
        }
        alias DListNodeType = DList!(ListNode).Node!(ListNode);
        DList!(ListNode)            nodes_list;
        HashMap!(K, DListNodeType*) nodes_map;
        HashMap!(K, CacheElement!V) main_map;

        RemovedEntryListener!(K, V) _removedEntryListener;

        ulong                       _maxLength = 64;
        ulong                       _maxSize;

    }

    @property
    public auto removedEntryListener(RemovedEntryListener!(K,V) rel) @nogc @safe {
        _removedEntryListener = rel;
        return this;
    }

    @property
    public auto maxLength(ulong s) @nogc @safe {
        _maxLength = s;
        return this;
    }

    @property
    public auto maxSize(ulong s) @nogc @safe {
        _maxSize = s;
        return this;
    }

    ~this() {
        clear();
    }

    invariant {
        assert(nodes_list.length  == nodes_map.length && nodes_list.length == main_map.length);
        assert(_maxLength >= main_map.length, "expected _size>=_map.length, %s>=%s".format(_maxLength, main_map.length));
    }

    void clear() @safe @nogc {
        // clear list and map
        while (nodes_list.length > 0) {
            auto ln = nodes_list.head;
            ListNode l = ln.v;
            K key = l.key;
            bool ok = 
                nodes_list.remove(ln) &&
                nodes_map.remove(key) &&
                main_map.remove(key);
            assert(ok);
        }
        assert(nodes_map.length == 0 && nodes_list.length == 0 && main_map.length == 0);
    }

    void handle_removal(K k, V v) @safe @nogc {
        if ( _removedEntryListener !is null ) {
            _removedEntryListener.add(k, v);
        }
    }

    Optional!V get(K k) @safe @nogc {
        auto v = main_map.get(k);
        if ( v.empty ) {
            return no!V;
        }
        //
        // check if this cacche element not expired
        // and if expired - remove it from cache, return no!V
        //
        CacheElement!V ce = v.front;
        return Optional!V(ce.value);
    }

    void put(K k, V v) @safe @nogc
    do {
        debug(cachetools) log("put %d\n", k);

        auto u = main_map.put(k, CacheElement!V(v));
        //
        // u is Optional!V which is not empty if we replaced old entry
        //
        if ( !u.empty ) {
            // we replaced some node
            auto np = nodes_map.get(k);
            assert(!np.empty);
            nodes_list.move_to_tail(np.front);
            if ( _removedEntryListener !is null ) {
                V old_value = u.front.value;
                handle_removal(k, old_value);
            }
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
        if ( main_map.length > _maxLength ) {
            debug(cachetools) log("evict, length before = %d, %d\n", main_map.length, nodes_map.length);
            // ok purge head
            auto head = nodes_list.head;
            auto eviction_key = head.v.key;
            auto ev = main_map.get(eviction_key);
            

            bool removed = nodes_map.remove(eviction_key);
            assert(removed);
            removed = nodes_list.remove(head);
            assert(removed);
            removed = main_map.remove(eviction_key);
            assert(removed);

            if ( _removedEntryListener !is null ) {
                assert(!ev.empty);
                V eviction_value = ev.front.value;
                handle_removal(eviction_key, eviction_value);
            }
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
        policy.maxLength(3);
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
        //out { assert(list.length < _limit);}
        do  {
            debug(cachetools) log("insert into removed list (%d)%d\n", k, list.length);
            if ( list.length == _limit) {
                assert(0, "You exceeded RemovedList limit");
            }
            list.insertBack(RemovedEntry!(K, V)(k, v));
            debug(cachetools) log("inserted\n");
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

@safe unittest {
    auto r = new RemovedEntriesList!(int, string)(16);
    () @nogc {
        assert(r.empty);

        r.add(1, "one");
        assert(!r.empty);
        auto e = r.get();
        assert(e.key == 1 && e.value == "one");
        assert(r.empty);
        foreach (i; 0..14) {
            r.add(i, "string");
        }

        while(!r.empty) {
            auto v = r.get();
        }
    }();
}

@safe unittest {

    alias K = int;
    alias V = string;
    FIFOPolicy!(K,V) cache = new FIFOPolicy!(K, V);
    RemovedEntryListener!(K, V) rel = new RemovedEntriesList!(K, V)();
    cache
        .removedEntryListener(rel)
        .maxLength(32);

    () @nogc {
        import std.range;
        import std.algorithm;

        SList!int removed_keys;

        foreach (i; 0..1000) {
            cache.put(i, "string");
            while(!rel.empty) {
                auto kv = rel.get();
                removed_keys.insertBack(kv.key);
            }
        }

        foreach(i; iota(968)) {
            assert(removed_keys.front == i);
            removed_keys.popFront();
        }

    }();
}

