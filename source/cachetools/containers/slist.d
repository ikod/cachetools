module cachetools.containers.slist;

private import stdx.allocator;
private import stdx.allocator.mallocator : Mallocator;

static void log(A...)(string fmt, A args) @nogc @trusted {
    import core.stdc.stdio;
    printf(fmt.ptr, args);
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

    ulong length() const pure @nogc @safe nothrow {
        return _length;
    }

    T front() pure @nogc @safe {
        return _first.v;
    }

    T back() pure @nogc @safe {
        return _last.v;
    }

    T popFront() @nogc @safe nothrow {
        T v = _first.v;
        auto next = _first._next;
        (() @trusted {dispose(allocator, _first);})();
        _first = next;
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
    void insertFront(T v) @nogc @safe nothrow {
        auto n = make!(_Node!T)(allocator);
        n.v = v;
        if ( _first !is null ) {
            n._next = _first;
        }
        _first = n;
        _length++;
    }

    void insertBack(T v) @nogc @safe nothrow {
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
}