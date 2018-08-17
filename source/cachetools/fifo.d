module cachetools.fifo;

import cachetools;
import cachetools.containers.hashmap;

///
/// CacheFIFO contains exactly `size` items
/// Replacement policy - evict oldest entry
///

static void log(A...)(string fmt, A args) @nogc @trusted {
    import core.stdc.stdio;
    printf(fmt.ptr, args);
}


//class CacheFIFO(K, V) : Cache!(K, V) {
//    private {
//        SList!K         _fifo;
//        HashMap!(K,V)   _map;
//    }
//
//    invariant {
//        import std.format;
//        assert(_fifo.length() <= _size);
//        assert(_fifo.length == _map.length, "_fifo.length != _map.length (%d != %d)".format(_fifo.length, _map.length));
//    }
//
//    this(int s = 64) @nogc @safe nothrow {
//        super(s);
//    }
//
//    override void put(K k, V v) @nogc @safe {
//        log("put enter\n");
//        ulong length_before = _map.length();
//        _map[k] = v;
//        ulong length_after = _map.length();
//        if ( length_before != length_after ) {
//            _fifo.insertBack(k);
//        }
//        if ( _fifo.length > _size ) {
//            // pop oldest
//            bool removed;
//            auto evicted = _fifo.popFront();
//            _map.remove(evicted, removed);
//        }
//        //_map[k] = v;
//        log("f:%d m:%d\n", _fifo.length(), _map.length());
//        log("put leave\n");
//    }
//
//    override ulong length() const @nogc {
//        return _fifo.length();
//    }
//
//}
private import stdx.allocator;
private import stdx.allocator.mallocator : Mallocator;


struct FIFOPolicy(K, Allocator = Mallocator) {
    private {
        struct ListNode {
            ListNode*   prev, next;
            K           key;
            
        }
        ListNode*               head;
        ListNode*               tail;
        HashMap!(K, ListNode*)  nodes;

        alias allocator = Allocator.instance;
    }
    ~this() {
        clear();
    }
    void clear() @safe @nogc {
        // clear list and map
        ListNode* n = head;
        while( n !is null ) {
            auto next = n.next;
            (() @trusted {dispose(allocator, n);})();
            n = next;
        }
        head = tail = null;
        nodes.clear();
    }
    // on insert we add key to the end of list
    void insert(K k) @safe @nogc {
        debug(cachetools) log("insert %d\n", k);
        bool map_inserted;
        auto n = make!(ListNode)(allocator);
        n.key = k;
        nodes.put(k, n, map_inserted);
        assert(map_inserted, "we expect we inserted new key");
        if ( tail is null ) {
            head = tail = n;
            return;
        }
        // append to tail
        n.prev = tail;
        tail.next = n;
        tail = n;
    }
    void remove(K k) @safe @nogc {
        debug(cachetools) log("remove %d\n", k);
        bool ok;
        ListNode* n = nodes.get(k, ok);
        assert(ok);
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
        nodes.remove(k, ok);
        assert(ok, "We expected key remove from map");
        (() @trusted {dispose(allocator, n);})();
    }
    // on update we MOVE key to the end of the list
    void update(K k) @safe @nogc {
        debug(cachetools) log("update %d\n", k);
        bool ok;
        ListNode* n = nodes.get(k, ok);
        assert(ok);
        assert(n !is null);
        if ( tail == n ) {
            debug(cachetools) log("was tail\n");
            return;
        }
        assert(n.next);
        debug(cachetools) log("repos\n");
        if ( head == n ) {
            debug(cachetools) log("was head\n");
            head = n.next;
        } else {
            n.prev.next = n.next;
        }
        // move this node to end
        n.next.prev = n.prev;
        n.next = null;
        tail = n;
        debug(cachetools) log("repositioned\n");
    }
    K evict() @safe @nogc {
        assert(head !is null);
        debug(cachetools) log("evict %d\n", head.key);
        return head.key;
    }
}