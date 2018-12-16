module cachetools.containers.lists;

private import std.experimental.allocator;
private import std.experimental.allocator.mallocator : Mallocator;
private import std.experimental.logger;
private import std.format;

private import cachetools.internal;

///
/// N-way multilist
struct MultiDList(T, int N, Allocator = Mallocator)
{
    alias allocator = Allocator.instance;
    struct Node {
        T payload;
        private:
        Link[N] links;
        Node* next(size_t i) @safe @nogc
        {
            return links[i].next;
        }
        Node* prev(size_t i) @safe @nogc
        {
            return links[i].prev;
        }
        alias payload this;
    }
    private 
    {
        struct Link
        {
            Node* prev;
            Node* next;
        }
        Node*[N]    _heads;
        Node*[N]    _tails;
        size_t      _length;
        
    }
    size_t length() const pure nothrow @safe @nogc {
        return _length;
    }

    Node* insert_last(T v) @safe nothrow
    out
    {
        assert(_length>0);
    }
    do
    {
        auto n = make!(Node)(allocator, v);
        static foreach(index;0..N) {
            if ( _heads[index] is null ) {
                _heads[index] = n;
            }
            n.links[index].prev = _tails[index];
            if ( _tails[index] !is null )
            {
                _tails[index].links[index].next = n;
            }
            _tails[index] = n;
        }
        _length++;
        return n;
    }

    void move_to_tail(Node* n, size_t i) @safe @nogc
    in
    {
        assert(i < N);
        assert(_length>0);
    }
    out
    {
        assert(_heads[i] !is null && _tails[i] !is null);
    }
    do
    {
        if ( n == _tails[i] ) {
            return;
        }
        // unlink
        if ( n.links[i].prev is null )
        {
            _heads[i] = n.links[i].next;
        }
        else
        {
            n.links[i].prev.links[i].next = n.links[i].next;
        }
        if ( n.links[i].next is null )
        {
            _tails[i] = n.links[i].prev;
        }
        else
        {
            n.links[i].next.links[i].prev = n.links[i].prev;
        }
        // insert back
        if ( _heads[i] is null ) {
            _heads[i] = n;
        }
        n.links[i].prev = _tails[i];
        if ( _tails[i] !is null )
        {
            _tails[i].links[i].next = n;
        }
        n.links[i].next = null;
        _tails[i] = n;
    }

    void remove(Node* n) nothrow @safe @nogc
    {
        if ( n is null || _length == 0 )
        {
            return;
        }
        static foreach(i;0..N) {
            if ( n.links[i].prev !is null ) {
                n.links[i].prev.links[i].next = n.links[i].next;
            }
            if ( n.links[i].next !is null ) {
                n.links[i].next.links[i].prev = n.links[i].prev;
            }
            if ( n == _tails[i] ) {
                _tails[i] = n.links[i].prev;
            }
            if ( n == _heads[i] ) {
                _heads[i] = n.links[i].next;
            }
        }
        (() @trusted {dispose(allocator, n);})();
        _length--;
    }
    Node* tail(size_t i) pure nothrow @safe @nogc
    {
        return _tails[i];
    }
    Node* head(size_t i) pure nothrow @safe @nogc
    {
        return _heads[i];
    }
    void clear() nothrow @safe @nogc
    {
        while(_length>0)
        {
            auto n = _heads[0];
            remove(n);
        }
    }
}

@safe unittest {
    import std.algorithm;
    import std.stdio;
    import std.range;
    struct Person
    {
        string name;
        int    age;
    }
    MultiDList!(Person*, 2) mdlist;
    Person[3] persons = [{"Alice", 11}, {"Bob", 9}, {"Carl", 10}];
    foreach(i; 0..persons.length)
    {
        mdlist.insert_last(&persons[i]);
    }
    enum NameIndex = 0;
    enum AgeIndex  = 1;
    assert(mdlist.head(NameIndex).payload.name == "Alice");
    assert(mdlist.head(AgeIndex).payload.age == 11);
    assert(mdlist.tail(NameIndex).payload.name == "Carl");
    assert(mdlist.tail(AgeIndex).payload.age == 10);
    auto alice = mdlist.head(NameIndex);
    auto bob = alice.next(NameIndex);
    auto carl = bob.next(NameIndex);
    mdlist.move_to_tail(alice, AgeIndex);
    assert(mdlist.tail(AgeIndex).payload.age == 11);
    mdlist.remove(alice);
    assert(mdlist.head(NameIndex).payload.name == "Bob");
    assert(mdlist.tail(NameIndex).payload.name == "Carl");
    assert(mdlist.head(AgeIndex).payload.age == 9);
    assert(mdlist.tail(AgeIndex).payload.age == 10);
    mdlist.insert_last(&persons[0]); // B, C, A
    mdlist.remove(carl); // B, A
    alice = mdlist.tail(NameIndex);
    assert(mdlist.length == 2);
    assert(alice.payload.name == "Alice");
    assert(alice.payload.age == 11);
    assert(mdlist.head(NameIndex).payload.name == "Bob");
    assert(mdlist.head(AgeIndex).payload.age == 9);
    assert(alice.prev(AgeIndex) == bob);
    assert(alice.prev(NameIndex) == bob);
    assert(bob.prev(AgeIndex) is null);
    assert(bob.prev(NameIndex) is null);
    assert(bob.next(AgeIndex) == alice);
    assert(bob.next(NameIndex) == alice);
    mdlist.insert_last(&persons[2]); // B, A, C
    carl = mdlist.tail(NameIndex);
    mdlist.move_to_tail(alice, AgeIndex);
    assert(bob.next(AgeIndex) == carl);
    assert(bob.next(NameIndex) == alice);
}

struct DList(T, Allocator = Mallocator) {
    this(this) @disable;

    struct Node(T) {
        T payload;
        private Node!T* prev;
        private Node!T* next;
        alias payload this;
    }
    private {
        alias allocator = Allocator.instance;
        Node!T* _head;
        Node!T* _tail;
        ulong   _length;
        
        Node!T* _freelist;
        uint    _freelist_len;
        enum    _freelist_len_max = 100;
    }

    invariant {
        assert
        (
            ( _length > 0 && _head !is null && _tail !is null) ||
            ( _length == 0 && _tail is null && _tail is null) ||
            ( _length == 1 && _tail == _head && _head !is null ),
            "length: %s, head: %s, tail: %s".format(_length, _head, _tail)
        );
    }

    ~this()
    {
        clear();
    }
    ulong length() const pure nothrow @safe @nogc {
        return _length;
    }

    void move_to_feelist(Node!T* n) @safe
    {
        if ( _freelist_len < _freelist_len_max )
        {
            n.next = _freelist;
            _freelist = n;
            ++_freelist_len;
        }
        else
        {
            (() @trusted {dispose(allocator, n);})();
        }
    }
    Node!T* peek_from_freelist() @safe
    {
        if ( _freelist_len )
        {
            _freelist_len--;
            auto r = _freelist;
            _freelist = r.next;
            r.next = r.prev = null;
            return r;
        }
        return null;
    }
    Node!T* insert_last(T v) @safe nothrow
    out
    {
        assert(_length>0);
        assert(_head !is null && _tail !is null);
    }
    do
    {
        Node!T* n;
        if ( _freelist_len == 0)
        {
            n = make!(Node!T)(allocator, v);
        }
        else
        {
            n = peek_from_freelist();
            n.payload = v;
        }
        if ( _head is null ) {
            _head = n;
        }
        n.prev = _tail;
        if ( _tail !is null )
        {
            _tail.next = n;
        }
        _tail = n;
        _length++;
        return n;
    }

    alias insertFront = insert_first;
    Node!T* insert_first(T v) @safe nothrow
    out
    {
        assert(_length>0);
        assert(_head !is null && _tail !is null);
    }
    do 
    {
        Node!T* n;
        if ( _freelist_len == 0)
        {
            n = make!(Node!T)(allocator, v);
        }
        else
        {
            n = peek_from_freelist();
            n.payload = v;
        }
        if ( _tail is null ) {
            _tail = n;
        }
        n.next = _head;
        if ( _head !is null )
        {
            _head.prev = n;
        }
        _head = n;
        _length++;
        return n;
    }
    void clear() @safe
    {
        Node!T* n = _head, next;
        while(n)
        {
            next = n.next;
            (() @trusted {dispose(allocator, n);})();
        }
        n = _freelist;
        while(n)
        {
            next = n.next;
            (() @trusted {dispose(allocator, n);})();
            n = next;
        }
        _length = 0;
        _freelist_len = 0;
        _head = _tail = _freelist = null;
    }
    bool popFront() @safe
    {
        if ( _length == 0 )
        {
            return false;
        }
        return remove(_head);
    }

    bool remove(Node!T* n) @safe @nogc
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
        _length--;
        move_to_feelist(n);
        return true;
    }

    void move_to_tail(Node!T* n) @safe @nogc
    in
    {
        assert(_length > 0);
        assert(_head !is null && _tail !is null);
    }
    out {
        assert(_tail == n && n.next is null);
    }
    do
    {
        if ( n == _tail ) {
            return;
        }
        // unlink
        if ( n.prev is null )
        {
            _head = n.next;
        }
        else
        {
            n.prev.next = n.next;
        }
        if ( n.next is null )
        {
            _tail = n.prev;
        }
        else
        {
            n.next.prev = n.prev;
        }
        // insert back
        if ( _head is null ) {
            _head = n;
        }
        n.prev = _tail;
        if ( _tail !is null )
        {
            _tail.next = n;
        }
        n.next = null;
        _tail = n;

        ////debug(cachetools) tracef("n: %s".format(*n));
        //assert(n.next !is null);
        ////debug tracef("m-t-t: %s, tail: %s", *n, *_tail);
        //assert(n.next, "non-tail entry have no 'next' pointer?");
        //if ( _head == n ) {
        //    assert(n.prev is null);
        //    _head = n.next;
        //} else {
        //    n.prev.next = n.next;
        //}
        //// move this node to end
        //n.next.prev = n.prev;
        //n.next = null;
        //tail.next = n;
        //_tail = n;
    }

    Node!T* head() @safe @nogc nothrow {
        return _head;
    }
    Node!T* tail() @safe @nogc nothrow {
        return _tail;
    }
}

struct SList(T, Allocator = Mallocator) {
    this(this) @safe
    {
        // copy items
        _Node!T* __newFirst, __newLast;
        auto f = _first;
        while(f)
        {
            auto v = f.v;
            auto n = make!(_Node!T)(allocator, v);
            if ( __newLast !is null ) {
                __newLast._next = n;
            } else {
                __newFirst = n;
            }
            __newLast = n;
            f = f._next;
        }
        _first = __newFirst;
        _last = __newLast;
    }

    package {
        struct _Node(T) {
            T v;
            _Node!T *_next;
        }
        alias allocator = Allocator.instance;

        ulong _length;
        _Node!T *_first;
        _Node!T *_last;
        
        _Node!T* _freelist;
        uint     _freelist_len;
        enum     _freelist_len_max = 100;
    }

    invariant {
        assert
        ( 
            ( _length > 0 && _first !is null && _last !is null) ||
            ( _length == 0 && _first is null && _last is null),
            "length: %d, first: %s, last: %s".format(_length, _first, _last)
        );
    }
    ~this()
    {
        clear();
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

    private void move_to_feelist(_Node!T* n) @safe
    {
        if ( _freelist_len < _freelist_len_max )
        {
            n._next = _freelist;
            _freelist = n;
            ++_freelist_len;
        }
        else
        {
            (() @trusted {dispose(allocator, n);})();
        }
    }
    private _Node!T* peek_from_freelist() @safe
    {
        if ( _freelist_len )
        {
            _freelist_len--;
            auto r = _freelist;
            _freelist = r._next;
            r._next = null;
            return r;
        }
        return null;
    }

    T popFront() @nogc @safe nothrow
    in { assert(_first !is null); }
    do {
        T v = _first.v;
        auto next = _first._next;
        _length--;
        move_to_feelist(_first);
        _first = next;
        if ( _first is null ) {
            _last = null;
        }
        return v;
    }
    void clear() @nogc @safe {
        _Node!T* n = _first;
        while( n !is null ) {
            auto next = n._next;
            (() @trusted {dispose(allocator, n);})();
            n = next;
        }
        n = _freelist;
        while( n !is null ) {
            auto next = n._next;
            (() @trusted {dispose(allocator, n);})();
            n = next;
        }
        _length = 0;
        _freelist_len = 0;
        _first = _last = null;
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

    void insertFront(T v) @safe nothrow
    out{ assert(_first !is null && _last !is null);}
    do {
        _Node!T* n;
        if ( _freelist_len == 0)
        {
            n = make!(_Node!T)(allocator, v);
        }
        else
        {
            n = peek_from_freelist();
            n.v = v;
        }
        if ( _first !is null ) {
            n._next = _first;
        }
        _first = n;
        if ( _last is null ) {
            _last = n;
        }
        _length++;
    }

    void insertBack(T v) @safe nothrow
    out{ assert(_first !is null && _last !is null);}
    do {
        _Node!T* n;
        if ( _freelist_len == 0)
        {
            n = make!(_Node!T)(allocator, v);
        }
        else
        {
            n = peek_from_freelist();
            n.v = v;
        }
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

@safe @nogc nothrow unittest {
    SList!int l;
    assert(l.length() == 0);
    l.insertFront(0);
    assert(l.front() == 0);
    l.popFront();
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
    //foreach(v; l[]){
    //    log("v=%d\n", *v);
    //}
    //log("---\n");
    bool removed;
    removed = l.remove_by_predicate((n){return n==2;});
    foreach(v; l[]){
        //log("v=%d\n", *v);
    }
    assert(removed);
    assert(l.length()==2);
    //log("---\n");
    removed = l.remove_by_predicate((n){return n==4;});
    foreach(v; l[]){
        //log("v=%d\n", *v);
    }
    assert(removed);
    assert(l.length()==1);
    //log("---\n");
    removed = l.remove_by_predicate((n){return n==3;});
    foreach(v; l[]){
        //log("v=%d\n", *v);
    }
    assert(removed);
    assert(l.length()==0);
    //log("---\n");
    removed = l.remove_by_predicate((n){return n==3;});
    foreach(v; l[]){
        //log("v=%d\n", *v);
    }
    assert(!removed);
    assert(l.length()==0);
    auto l1 = SList!int();
    foreach(i;0..100) {
        l1.insertBack(i);
    }
    while(l1.length) {
        l1.popFront();
    }
    foreach(i;0..100) {
        l1.insertFront(i);
    }
    while(l1.length) {
        l1.popFront();
    }
}

@safe @nogc nothrow unittest {
    DList!int dlist;
    auto n0 = dlist.insertFront(0);
    assert(dlist.head.payload == 0);
    dlist.remove(n0);
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
    assert(dlist.head.payload == 2);
    assert(dlist.tail.payload == 1);
}

private uint useFreePosition(ubyte[] m) @safe @nogc
{
    import core.bitop: bsf;
    //
    // find free position, mark it as used and return it
    // least significant bit in freeMap[0] means _nodes[0]
    // most significant bit in freeMap[$-1] means nodes[$-1]
    //
    auto l = m.length;
    for(uint i=0; i < l;i++)
    {
        ubyte v = m[i];
        if ( v < 255 )
        {
            auto p = bsf(v ^ 0xff);
            m[i] += 1 << p;
            return (i<<3)+p;
        }
    }
    assert(0);
}
private void markFreePosition(ubyte[] m, size_t position) @safe @nogc
{
    auto p = position >> 3;
    auto b = position & 0x7;
    m[p] &= (1<<b)^0xff;
}

@safe unittest
{
    import std.algorithm.comparison: equal;
    ubyte[] map = [0,0];
    auto p = useFreePosition(map);
    assert(p == 0, "expected 0, got %s".format(p));
    assert(map[0] == 1);
    p = useFreePosition(map);
    assert(p == 1, "expected 1, got %s".format(p));
    map = [255,0];
    p = useFreePosition(map);
    assert(p == 8, "expected 8, got %s".format(p));
    assert(map[1] == 1);
    map = [255,0x01];
    p = useFreePosition(map);
    assert(p == 9, "expected 9, got %s".format(p));
    assert(equal(map, [0xff, 0x03]));
    markFreePosition(map, 8);
    assert(equal(map, [0xff, 0x02]), "got %s".format(map));
    markFreePosition(map, 9);
    assert(equal(map, [0xff, 0x00]), "got %s".format(map));
    markFreePosition(map, 0);
    assert(equal(map, [0xfe, 0x00]), "got %s".format(map));
}

struct CompressedList(T, Allocator = Mallocator)
{
    alias allocator = Allocator.instance;
    alias StoredT = StoredType!T;
    enum PageSize = 128;    // in bytes
    static assert(PageSize/Node.sizeof > 1, "Node is too large to use this List, use DList instead");
    enum NodesPerPage = PageSize/Node.sizeof;
    enum BitMapLength = NodesPerPage / 8;
    ///
    /// unrolled list with support only for:
    /// 1) insert/delete front
    /// 2) insert/delete back
    /// 3) keep smart-pointer to arbitrary element
    /// 4) remove element by smart-pointer
    struct Page
    {
        ///
        /// Page is fixed-length array of list Nodes
        /// with batteries
        ///
        ubyte               count;
        ubyte[BitMapLength] freeMap;
        Page*               _nextPage;
        Page*               _prevPage;
        byte                _firstNode;
        byte                _lastNode;
        Node[NodesPerPage]  _nodes;
    }
    struct Node
    {
        StoredT v;
        byte    n; // next index
        byte    p; // prev index
    }
    private
    {
        Page*   _pages_first, _pages_last;
        ulong   _length;
        Page*   _freelist;
        int     _freelist_len;
        enum    _freelist_len_max = 100;
    }
    private void move_to_feelist(Page* page) @safe @nogc
    {
        if ( _freelist_len >= _freelist_len_max )
        {
            debug(cachetools) safe_tracef("dispose page");
            () @trusted {dispose(allocator, page);}();
            return;
        }
        debug(cachetools) safe_tracef("put page in freelist");
        page._nextPage = _freelist;
        _freelist = page;
        _freelist_len++;
    }
    private Page* peek_from_freelist() @safe @nogc
    {
        if ( _freelist is null )
        {
            return null;
        }
        Page* p = _freelist;
        _freelist = p._nextPage;
        _freelist_len--;
        assert(_freelist_len>=0 && _freelist_len < _freelist_len_max);
        p._nextPage = p._prevPage = null;
        return p;
    }
    bool empty() @safe const
    {
        return _length == 0;
    }
    ulong length() @safe const
    {
        return _length;
    }
    T front() @safe
    {
        if ( empty )
        {
            assert(0, "Tried to access front of empty list");
        }
        Page* p = _pages_first;
        assert( p !is null);
        assert( p.count > 0 );
        with(p)
        {
            return _nodes[_firstNode].v;
        }
    }
    void popFront() @safe
    {
        if ( empty )
        {
            assert(0, "Tried to popFront from empty list");
        }
        _length--;
        Page* page = _pages_first;
        assert(page !is null);
        with (page) {
            assert(count>0);
            auto f = _firstNode;
            auto n = _nodes[f].n;
            markFreePosition(freeMap, f);
            count--;
            _firstNode = n;
        }
        if ( page.count == 0 )
        {
            // relase this page
            _pages_first = page._nextPage;
            move_to_feelist(page);
            if ( _pages_first is null )
            {
                _pages_last = null;
            }
        }
    }
    void insertFront(T v) @safe
    {
        _length++;
        Page* page = _pages_first;
        if ( page is null )
        {
            page = peek_from_freelist();
            _pages_first = _pages_last = page;
        }
        if ( page is null )
        {
            page = make!Page(allocator);
            page._firstNode = page._lastNode = -1;
            _pages_first = _pages_last = page;
        }
        if (page.count == NodesPerPage)
        {
            Page* new_page = peek_from_freelist();
            if ( new_page is null )
            {
                debug(cachetools) safe_tracef("Create new page");
                new_page = make!Page(allocator);
            }
            new_page._firstNode = page._lastNode = -1;
            new_page._nextPage = page;
            page._prevPage = new_page;
            _pages_first = new_page;
            page = new_page;
        }
        // there is free space
        auto index = useFreePosition(page.freeMap);
        assert(index < NodesPerPage);
        page._nodes[index].v = v;
        page._nodes[index].p = -1;
        page._nodes[index].n = page._firstNode;
        if (page.count == 0)
        {
            page._firstNode = page._lastNode = cast(ubyte)index;
        }
        else
        {
            page._nodes[page._firstNode].p = cast(ubyte)index;
            page._firstNode = cast(ubyte)index;
        }
        page.count++;
        debug(cachetools) safe_tracef("page: %s", *page);
    }
    void insertBack(T v) @safe
    {
        _length++;
        Page* page = _pages_last;
        if ( page is null )
        {
            page = peek_from_freelist();
            _pages_first = _pages_last = page;
        }
        if ( page is null )
        {
            page = make!Page(allocator);
            page._firstNode = page._lastNode = -1;
            _pages_first = _pages_last = page;
        }
        if (page.count == NodesPerPage)
        {
            Page* new_page = peek_from_freelist();
            if ( new_page is null )
            {
                debug(cachetools) safe_tracef("Create new page");
                new_page = make!Page(allocator);
            }
            new_page._firstNode = page._lastNode = -1;
            new_page._prevPage = page;
            page._nextPage = new_page;
            _pages_last = new_page;
            page = new_page;
        }
        // there is free space
        auto index = useFreePosition(page.freeMap);
        assert(index < NodesPerPage);
        page._nodes[index].v = v;
        page._nodes[index].n = -1;
        page._nodes[index].p = page._lastNode;
        if (page.count == 0)
        {
            page._firstNode = page._lastNode = cast(ubyte)index;
        }
        else
        {
            page._nodes[page._lastNode].n = cast(ubyte)index;
            page._lastNode = cast(ubyte)index;
        }
        page.count++;
        debug(cachetools) safe_tracef("page: %s", *page);
    }
}

@safe unittest
{
    import std.experimental.logger;
    globalLogLevel = LogLevel.trace;
    CompressedList!int  list;
    foreach(i;1..19)
    {
        list.insertFront(i);
        assert(list.front == i);
    }
    assert(list.length == 18);
    list.popFront();
    assert(list.length == 17);
    assert(list.front == 17);
    list.popFront();
    assert(list.length == 16);
    assert(list.front == 16);
    while( !list.empty )
    {
        list.popFront();
    }
    foreach(i;1..19)
    {
        list.insertFront(i);
        assert(list.front == i);
    }
    while( !list.empty )
    {
        list.popFront();
    }
    list.insertBack(99);
    assert(list.front == 99);
    list.insertBack(100);
    assert(list.front == 99);
    list.insertFront(98);
}