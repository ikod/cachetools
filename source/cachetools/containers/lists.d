module cachetools.containers.lists;

private import stdx.allocator;
private import stdx.allocator.mallocator : Mallocator;

static void log(A...)(string fmt, A args) @nogc @trusted {
    import core.stdc.stdio;
    printf(fmt.ptr, args);
}

struct DList(T, Allocator = Mallocator) {
    this(this) @disable;
    struct Node(T) {
        T v;
        Node!T* next;
        Node!T* prev;
    }
    private {
        alias allocator = Allocator.instance;
        Node!T* _head;
        Node!T* _tail;
        ulong   _length;
    }

    invariant {
        assert
        (
            ( _length > 0 && _head !is null && _tail !is null) ||
            ( _length == 0 && _tail is null && _tail is null)
        );
    }

    ulong length() const pure nothrow @safe @nogc {
        return _length;
    }
    Node!T* insert_last(T v) @safe @nogc nothrow {
        auto n = make!(Node!T)(allocator);
        n.v = v;
        if ( _tail is null )
        {
            _head = _tail = n;
        }
        else
        {
            n.prev = _tail;
            _tail.next = n;
            _tail = n;
        }
        _length++;
        return n;
    }
    Node!T* insert_first(T v) @safe @nogc nothrow
    out
    {
        assert(_length>0);
        assert(_head !is null && _tail !is null);
    }
    do 
    {
        auto n = make!(Node!T)(allocator);
        n.v = v;
        if ( _head is null )
        {
            _head = _tail = n;
        }
        else
        {
            _head.prev = n;
            n.next = _head;
            _head = n;
        }
        _length++;
        return n;
    }

    bool remove(Node!T* n) @safe @nogc nothrow 
    in {assert(_length>0);}
    do {
        if ( n.prev ) {
            n.prev.next = n.next;
        }
        if ( n.next ) {
            n.next.prev = n.prev;
        }
        if ( n == _tail ) {
            _tail = n.prev;
        }
        if ( n == _head ) {
            _head = n.next;
        }
        (() @trusted {dispose(allocator, n);})();
        _length--;
        return true;
    }

    void move_to_tail(Node!T* n) @safe @nogc nothrow
    in
    {
        assert(_length > 0);
        assert(_head !is null && _tail !is null);
    }
    do
    {
        if ( n == _tail ) {
            return;
        }
        assert(n.next);
        if ( _head == n ) {
            _head = n.next;
        } else {
            n.prev.next = n.next;
        }
        // move this node to end
        n.next.prev = n.prev;
        n.next = null;
        _tail = n;
    }

    Node!T* head() @safe @nogc nothrow {
        return _head;
    }
    Node!T* tail() @safe @nogc nothrow {
        return _tail;
    }
}

struct SList(T, Allocator = Mallocator) {
    this(this) @disable;

    private {
        struct _Node(T) {
            T v;
            _Node!T *_next;
        }
        alias allocator = Allocator.instance;

        ulong _length;
        _Node!T *_first;
        _Node!T *_last;
    }

    invariant {
        assert
        ( 
            ( _length > 0 && _first !is null && _last !is null) ||
            ( _length == 0 && _first is null && _last is null)
        );
    }

    ulong length() const pure @nogc @safe nothrow {
        return _length;
    }

    bool empty() @nogc @safe const {
        return _length == 0;
    }
    
    T front() pure @nogc @safe {
        return _first.v;
    }

    T back() pure @nogc @safe {
        return _last.v;
    }

    T popFront() @nogc @safe nothrow
    in { assert(_first !is null); }
    do {
        T v = _first.v;
        auto next = _first._next;
        (() @trusted {dispose(allocator, _first);})();
        _first = next;
        if ( _first is null ) {
            _last = null;
        }
        _length--;
        return v;
    }
    void clear() @nogc @safe {
        _Node!T* n = _first;
        while( n !is null ) {
            auto next = n._next;
            (() @trusted {dispose(allocator, n);})();
            n = next;
        }
    }
    private struct Range(T) {
        private {
            _Node!T *current;
        }
        auto front() pure nothrow @safe @nogc @property {
            return &current.v;
        }
        void popFront() @safe @nogc nothrow {
            current = current._next;
        }
        bool empty() pure const nothrow @safe @nogc @property {
            return current is null;
        }
    }
    alias opSlice = range;
    auto range() {
        return Range!T(_first);
    }

    void insertFront(T v) @nogc @safe nothrow
    out{ assert(_first !is null && _last !is null);}
    do {
        auto n = make!(_Node!T)(allocator);
        n.v = v;
        if ( _first !is null ) {
            n._next = _first;
        }
        _first = n;
        if ( _last is null ) {
            _last = n;
        }
        _length++;
    }

    void insertBack(T v) @nogc @safe nothrow
    out{ assert(_first !is null && _last !is null);}
    do {
        auto n = make!(_Node!T)(allocator);
        n.v = v;
        if ( _last !is null ) {
            _last._next = n;
        } else {
            _first = n;
        }
        _last = n;
        _length++;
    }
    bool remove_by_predicate(scope bool delegate(T) @safe @nogc nothrow f) @nogc @trusted nothrow {
        bool removed;
        _Node!T *current = _first;
        _Node!T *prev = null;
        while (current !is null) {
            auto next = current._next;
            if ( !f(current.v) ) {
                prev = current;
                current = next;
                continue;
            }
            // do remove
            _length--;
            removed = true;
            dispose(allocator, current);
            if ( prev is null ) {
                _first = next;                    
            } else {
                prev._next = next;
            }
            if ( next is null ) {
                _last = prev;
            }
        }
        return removed;
    }
}

@safe @nogc unittest {
    SList!int l;
    assert(l.length() == 0);
    l.insertBack(1);
    assert(l.front() == 1);
    assert(l.length() == 1);
    l.insertBack(2);
    assert(l.front() == 1);
    assert(l.back() == 2);
    assert(l.length() == 2);
    //log(l.range());
    l.popFront();
    assert(l.front() == 2);
    assert(l.back() == 2);
    assert(l.length() == 1);
    l.insertBack(3);
    l.insertBack(4);
    foreach(v; l[]){
        log("v=%d\n", *v);
    }
    log("---\n");
    bool removed;
    removed = l.remove_by_predicate((n){return n==2;});
    foreach(v; l[]){
        log("v=%d\n", *v);
    }
    assert(removed);
    assert(l.length()==2);
    log("---\n");
    removed = l.remove_by_predicate((n){return n==4;});
    foreach(v; l[]){
        log("v=%d\n", *v);
    }
    assert(removed);
    assert(l.length()==1);
    log("---\n");
    removed = l.remove_by_predicate((n){return n==3;});
    foreach(v; l[]){
        log("v=%d\n", *v);
    }
    assert(removed);
    assert(l.length()==0);
    log("---\n");
    removed = l.remove_by_predicate((n){return n==3;});
    foreach(v; l[]){
        log("v=%d\n", *v);
    }
    assert(!removed);
    assert(l.length()==0);
    auto l1 = SList!int();
    foreach(i;0..100) {
        l1.insertBack(i);
    }
    while(l.length) {
        l1.popFront();
    }
    foreach(i;0..100) {
        l1.insertFront(i);
    }
    while(l.length) {
        l1.popFront();
    }
}

@safe unittest {
    DList!int dlist;
    auto n1 = dlist.insert_last(1);
    assert(dlist.length == 1);
    dlist.remove(n1);
    assert(dlist.length == 0);

    n1 = dlist.insert_first(1);
    assert(dlist.length == 1);
    dlist.remove(n1);
    assert(dlist.length == 0);

    n1 = dlist.insert_first(1);
    auto n2 = dlist.insert_last(2);
    assert(dlist.length == 2);
    dlist.move_to_tail(n1);
    assert(dlist.head.v == 2);
    assert(dlist.tail.v == 1);
}