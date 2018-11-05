module cachetools.fifo;

import cachetools.interfaces;
import cachetools.containers.hashmap;
import cachetools.containers.lists;

import std.typecons;
import std.exception;
import std.experimental.logger;

import optional;

///
/// CacheFIFO contains exactly `size` items
/// Replacement policy - evict oldest entry
///

private import std.format;
private import stdx.allocator;
private import stdx.allocator.mallocator : Mallocator;

class FIFOPolicy(K, V, Allocator = Mallocator) : CachePolicy!(K, V) {
    private {
        alias DListNodeType = DList!(ListNode).Node!(ListNode);

        struct CacheElement(V) {
            package {
                V               _value;
                size_t          _size;
                DListNodeType*  _list_node;
                //SysTime _created;
                //SysTime _updated;
                //SysTime _accessed;
            }

            @property
            V value() const {
                return _value;
            }
        }

        alias allocator = Allocator.instance;

        struct ListNode {
            K       key;
            ulong   _hits;
            bool    _rbit;
        }

        DList!(ListNode)            main_list;
        OAHashMap!(K, CacheElement!V) main_map;

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
        assert(main_list.length == main_map.length);
        assert(_maxLength >= main_map.length, "expected _size>=_map.length, %s>=%s".format(_maxLength, main_map.length));
    }

    void clear() @safe @nogc {
        // clear list and map
        while (main_list.length > 0) {
            auto ln = main_list.head;
            ListNode l = ln.payload;
            K key = l.key;
            bool ok = 
                main_list.remove(ln) &&
                main_map.remove(key);
            assert(ok);
        }
        assert(main_list.length == 0 && main_map.length == 0);
    }

    void handle_removal(K k, V v) @safe @nogc {
        if ( _removedEntryListener ) {
            _removedEntryListener.add(k, v);
        }
    }

    Optional!V get(K k) @safe @nogc {
        debug(cachetools) tracef("get %s", k);
        auto v = k in main_map;
        if ( !v ) {
            return no!V;
        }
        auto list_pointer = v._list_node;
        list_pointer.payload._hits++;
        list_pointer.payload._rbit = true;
        return Optional!V((*v).value);
    }

    void put(K k, V v) @safe @nogc
    do {
        debug(cachetools) tracef("put %s", k);

        if ( auto cep = k in main_map ) {
            // update old node
            if ( _removedEntryListener ) {
                handle_removal(k, cep._value);
            }
            cep._value = v;
            auto node_pointer = cep._list_node;
            main_list.move_to_tail(node_pointer);
        }
        else
        {
            // insert new node
            ListNode new_node = {key: k};
            auto node_pointer = main_list.insert_last(new_node);
            CacheElement!(V) ce = {
                _value:v,
                _list_node: node_pointer
            };
            auto u = main_map.put(k, ce);
            assert(u.empty);
        }
        //
        // check if we have to purge something
        //
        if ( main_map.length > _maxLength ) {
            debug(cachetools) tracef("evict, length before = %d", main_map.length);
            // ok purge head
            auto head = main_list.head;
            while ( head.payload._rbit ) {
                debug(cachetools) tracef("second chance for key %s", head.payload.key);
                head.payload._rbit = false;
                main_list.move_to_tail(head);
                head = main_list.head;
            }
            auto eviction_key = head.payload.key;
            auto ev = main_map.get(eviction_key);

            debug(cachetools) tracef("eviction_key: %s", eviction_key);

            bool removed = main_list.remove(head);
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
        return main_list.length();
    }

    bool remove(K k) @safe @nogc {
        debug(cachetools) tracef("remove %d", k);

        auto cep = k in main_map;
        if ( !cep ) {
            return false;
        }
        auto np = cep._list_node;
        bool ok = main_list.remove(np) && main_map.remove(k);
        return ok;
    }
}

@safe unittest {
    import std.experimental.logger;
    import std.format;

    globalLogLevel = LogLevel.info;
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
        // oldest key '1' saved by 'second chance algorithm', next to remove - '2'
        v = policy.get(2);
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

