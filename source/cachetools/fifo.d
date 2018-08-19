module cachetools.fifo;

import cachetools;
import cachetools.containers.hashmap;
import cachetools.containers.slist;

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
            ListNode*   prev, next;
            K           key;
        }
        ListNode*               head;
        ListNode*               tail;
        DList!ListNode          nodes_list;
        HashMap!(K, ListNode*)  nodes_map;

        HashMap!(K, V)          _map;
        ulong                   _size=64;
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
        assert(_map.length  == nodes_map.length);
        assert(_size >= _map.length, "expected _size>=_map.length, %s>=%s".format(_size, _map.length));
    }

    void clear() @safe @nogc {
        // clear list and map
        ListNode* n = head;
        while( n !is null ) {
            auto v = _map.get(n.key);
            assert(!v.empty);
            if ( _onRemoval ) {
                _onRemoval(n.key, v.front);
            }
            auto next = n.next;
            (() @trusted {dispose(allocator, n);})();
            n = next;
        }
        head = tail = null;
        //
        //
        //
        while (nodes_list.length > 0) {
            auto ln = nodes_list.head;
            ListNode l = ln.v;
            K key = l.key;
            nodes_list.remove(ln);
        }
        nodes_map.clear();
        _map.clear();
    }

    Optional!V get(K k) {
        return _map.get(k);
    }

    void put(K k, V v) @safe @nogc
    do {
        debug(cachetools) log("put %d\n", k);
        auto u = _map.put(k, v);
        if ( !u.empty ) {
            // we replaced some node
            if ( _onRemoval ) _onRemoval(k, u.front);
            auto n = nodes_map.get(k);
            assert(!n.empty);
            ListNode* np = n.front;
            assert(np !is null);
            if ( tail == np ) {
                debug(cachetools) log("was tail\n");
                return;
            }
            assert(np.next);
            debug(cachetools) log("repos\n");
            if ( head == n ) {
                debug(cachetools) log("was head\n");
                head = np.next;
            } else {
                np.prev.next = np.next;
            }
            // move this node to end
            np.next.prev = np.prev;
            np.next = null;
            tail = np;
            debug(cachetools) log("repositioned\n");
            return;
        }
        auto nn = make!(ListNode)(allocator);
        nn.key = k;
        nodes_map.put(k, nn);
        if ( tail is null ) {
            head = tail = nn;
            return;
        }
        // append to tail
        nn.prev = tail;
        tail.next = nn;
        tail = nn;
        //
        // check if we have to purge something
        //
        if ( _map.length > _size ) {
            debug(cachetools) log("evict, length before = %d, %d\n", _map.length, nodes_map.length);
            // ok purge head
            auto ek = head.key;
            auto ev = _map.get(ek);
            assert(!ev.empty);
            if ( _onRemoval ) _onRemoval(ek, ev.front);

            bool removed = _map.remove(ek);
            assert(removed, "We expected key remove from value map");

            auto n = nodes_map.get(ek);
            assert(!n.empty);
            ListNode* np = n.front;
            if ( np.prev ) {
                np.prev.next = np.next;
            }
            if ( np.next ) {
                np.next.prev = np.prev;
            }
            if ( np == tail ) {
                tail = np.prev;
            }
            if ( np == head ) {
                head = np.next;
            }
            removed = nodes_map.remove(ek);
            assert(removed, "We expected key remove from nodes map");
            (() @trusted {dispose(allocator, np);})();
            debug(cachetools) log("evict, length after = %d, %d\n", _map.length, nodes_map.length);
        }
    }
    ulong length() const {
        return _map.length();
    }
    bool remove(K k) @safe @nogc {
        import std.conv;
        debug(cachetools) log("remove %d\n", k);
        bool ok;
        auto v = nodes_map.get(k);
        if ( v == none ) {
            return false;
        }
        ListNode* n = v.front;
        if ( n.prev ) {
            n.prev.next = n.next;
        }
        if ( n.next ) {
            n.next.prev = n.prev;
        }
        if ( n == tail ) {
            tail = n.prev;
        }
        if ( n == head ) {
            head = n.next;
        }
        ok = nodes_map.remove(k) && _map.remove(k);
        (() @trusted {dispose(allocator, n);})();
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