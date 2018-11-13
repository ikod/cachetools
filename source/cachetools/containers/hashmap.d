module cachetools.containers.hashmap;

import std.traits;
import std.experimental.logger;
import std.format;
import std.typecons;

import core.memory;
import core.bitop;

import optional;

private import std.experimental.allocator;
private import std.experimental.allocator.mallocator: Mallocator;

private import cachetools.hash;
private import cachetools.containers.lists;

// K (key type) must be of value type without references.


//struct HashMap(K, V, Allocator = Mallocator) {
//    /// Various statistics collector
//    struct Stat {
//        ulong   gets;             /// # of get() calls
//        ulong   puts;             /// # of put() calls
//        ulong   hits;
//        ulong   inserts;
//        ulong   removes;
//        ulong   resizes;
//        size_t  key_space;
//        size_t  value_space;
//    }
//
//    private {
//        // resize load_factor.
//        // Trigger for resize.
//        // if load factor (num of elements in hash table divide hash rows) reach resize_load_factor then we 
//        // start resize process
//        enum    resize_load_factor = 3.0;
//        // resize_step.
//        // during resize we have to transfer all items from main table to 'resize' table 
//        // (using new hash rows and hash calculatons) and then use this new table as main.
//        // We do not transfer all items at once as it can take too much time. We transfer
//        // 'resize_step' items on each iteration while there are any items in main table.
//        enum    resize_step = 1000;
//
//        alias   allocator = Allocator.instance;
//        alias   NodeT = _Node;
//        struct _Node {
//            // node of the chain in bucket
//            hash_t  hash;
//            K       key;
//            V       value;
//        }
//        struct _Bucket {
//            // hash bucket 
//            SList!_Node _chain;
//        }
//        struct _Table {
//            ulong     _length;          // entries in table
//            ulong     _buckets_size;    // buckets in table
//            _Bucket[] _buckets;
//
//            float load_factor() const pure @safe @nogc nothrow {
//                if ( _length == 0 || _buckets_size == 0 ) {
//                    return 0.0;
//                }
//                return float(_length)/_buckets_size;
//            }
//
//            bool overloaded() const @safe @nogc nothrow pure {
//                return load_factor() > resize_load_factor;
//            }
//        }
//        bool    _in_resize;
//        size_t  _in_resize_bucket_index;
//        _Table  _main_table;
//        _Table  _resize_table;
//        Stat    _stat;
//    }
//
//    ~this() @safe @nogc {
//        clear();
//    }
//
//    invariant {
//        assert(_in_resize ? _resize_table._buckets_size > 0 : _resize_table._buckets_size == 0);
//    }
//    ///
//    /// We detected that it's time to resize.
//    /// 1. calculate new buckets_size
//    /// 2. allocate new buckets array
//    ///
//    private void start_resize() @nogc @safe {
//        _stat.resizes++;
//        _in_resize = true;
//        _in_resize_bucket_index = 0;
//        _resize_table._buckets_size = _main_table._buckets_size * grow_factor;
//        assert(_resize_table._buckets is null);
//        _resize_table._buckets = makeArray!(_Bucket)(allocator, _resize_table._buckets_size);
//        debug(cachetools) tracef("start resize from %d to %d", _main_table._buckets_size, _resize_table._buckets_size);
//    }
//
//    private void do_resize_step() @nogc @safe {
//        assert(_in_resize);
//        _Bucket* b = &_main_table._buckets[_in_resize_bucket_index];
//        for(int i; i < resize_step && _main_table._length > 0; i++) {
//            debug(cachetools) trace("resize_step");
//            while ( b._chain.length == 0 ) {
//                _in_resize_bucket_index++;
//                if ( _in_resize_bucket_index >= _main_table._buckets_size ) {
//                    assert(_main_table._length == 0);
//                    stop_resize();
//                    debug(cachetools) trace("done\n");
//                    return;
//                }
//                b = &_main_table._buckets[_in_resize_bucket_index];
//            }
//            debug(cachetools) tracef("bucket length = %d", b._chain.length);
//            auto n = b._chain.front;
//            b._chain.popFront;
//            _main_table._length--;
//            auto computed_hash = n.hash;
//            _Table *table = &_resize_table;
//            hash_t h = computed_hash % table._buckets_size;
//            table._buckets[h]._chain.insertFront(n);
//            table._length++;
//        }
//        debug(cachetools) trace("resize_step done");
//        if ( _main_table._length == 0 ) {
//            stop_resize();
//        }
//    }
//
//    ///
//    /// All elements transfered to 'resize' table.
//    /// free anything from main table and 'swap' content of main and resize tables
//    /// 
//    private void stop_resize() @nogc @safe {
//        assert(_in_resize);
//        assert(_main_table._length == 0);
//        debug(cachetools) trace("stop resize");
//        _in_resize = false;
//        // free old buckets array in main table
//        (() @trusted {dispose(allocator, _main_table._buckets);})();
//        // transfer everything from resize table to main table
//        _main_table._length = _resize_table._length;
//        _main_table._buckets = _resize_table._buckets;
//        // initialize resize_table
//        _main_table._buckets_size = _resize_table._buckets_size;
//        _resize_table = _Table.init;
//    }
//
//    ulong length() const pure @nogc @safe {
//        return _main_table._length + _resize_table._length;
//    }
//
//    void clear() @nogc @safe {
//        clear_table(&_main_table);
//        clear_table(&_resize_table);
//        _stat = Stat.init;
//    }
//
//    private void clear_table(_Table* t) @nogc @safe nothrow {
//        if ( t._buckets is null ) {
//            return;
//        }
//        foreach(ref b; t._buckets) {
//            b._chain.clear();
//        }
//        (() @trusted {dispose(allocator, t._buckets);})();
//        t._length = 0;
//        t._buckets = null;
//        t._buckets_size = 0;
//    }
//
//    /// return true if removed from table, false otherwise
//    private bool remove_from_table(_Table* t, K k) @nogc @safe nothrow {
//        bool removed;
//        immutable ulong computed_hash = hash_function(k);
//        immutable ulong hash = computed_hash % t._buckets_size;
//
//        auto bucket = &t._buckets[hash];
//        removed = bucket._chain.remove_by_predicate((n) @nogc {return n.key==k;});
//        return removed;
//    }
//
//    /// return true if updated in table
//    private Optional!V update_in_table(_Table* t, K k, V v, hash_t computed_hash) @nogc @safe {
//        immutable ulong hash = computed_hash % t._buckets_size;
//
//        Optional!V r;
//        auto np = t._buckets[hash]._chain._first;
//        while ( np ) {
//            if (np.v.key == k) {
//                r = np.v.value;
//                np.v.value = v;
//                break;
//            }
//            np = np._next;
//        }
//        return r;
//    }
//
//    Optional!V get(K k) @safe @nogc {
//        if ( _main_table._buckets_size == 0 ) {
//            _main_table._buckets_size = initial_buckets_size;
//            _main_table._buckets = makeArray!(_Bucket)(allocator, _main_table._buckets_size);
//        }
//
//        if ( _in_resize ) {
//            do_resize_step();
//        }
//
//        auto r = no!V;
//        _stat.gets++;
//        immutable ulong computed_hash = hash_function(k);
//        _Table *t = &_main_table;
//        ulong hash = computed_hash % t._buckets_size;
//        auto chain = t._buckets[hash]._chain[];
//        foreach(nodep; chain) {
//            if (nodep.key == k) {
//                _stat.hits++;
//                r = nodep.value;
//                break;
//            }
//        }
//        if ( !_in_resize ) {
//            return r;
//        }
//        t = &_resize_table;
//        hash = computed_hash % t._buckets_size;
//        chain = t._buckets[hash]._chain[];
//        foreach(nodep; chain) {
//            if (nodep.key == k) {
//                _stat.hits++;
//                r = nodep.value;
//                break;
//            }
//        }
//        return r;
//    }
//
//    ///
//    /// return pointer to value if key present
//    ///
//    V* opBinaryRight(string op)(const K k) @safe @nogc if (op == "in") {
//
//        if ( _main_table._buckets_size == 0 ) {
//            _main_table._buckets_size = initial_buckets_size;
//            _main_table._buckets = makeArray!(_Bucket)(allocator, _main_table._buckets_size);
//        }
//
//        if ( _in_resize ) {
//            do_resize_step();
//        }
//
//        immutable ulong computed_hash = hash_function(k);
//        _Table *t = &_main_table;
//        ulong hash = computed_hash % t._buckets_size;
//        auto np = t._buckets[hash]._chain._first;
//        while (np) {
//            if (np.v.key == k) {
//                _stat.hits++;
//                return &np.v.value;
//            }
//            np = np._next;
//        }
//        if ( !_in_resize ) {
//            return null;
//        }
//        t = &_resize_table;
//        hash = computed_hash % t._buckets_size;
//        np = t._buckets[hash]._chain._first;
//        while (np) {
//            if (np.v.key == k) {
//                _stat.hits++;
//                return &np.v.value;
//            }
//            np = np._next;
//        }
//        return null;
//    }
//
//    Optional!V put(K k, V v) @nogc @safe {
//        if ( _main_table._buckets_size == 0 ) {
//            _main_table._buckets_size = initial_buckets_size;
//            _main_table._buckets = makeArray!(_Bucket)(allocator, _main_table._buckets_size);
//        }
//
//        _stat.puts++;
//
//        if ( !_in_resize && _main_table.overloaded() ) {
//            start_resize();
//        }
//
//        if ( _in_resize ) {
//            do_resize_step();
//        }
//        
//        immutable computed_hash = hash_function(k);
//
//
//        auto u = update_in_table(&_main_table, k, v, computed_hash);
//
//        if ( u != none ) {
//            return u;
//        }
//        if ( _in_resize ) {
//            u = update_in_table(&_resize_table, k, v, computed_hash);
//        }
//
//        if ( u != none ) {
//            return u;
//        }
//        //
//        // key is not in map.
//        // insert it in proper table.
//        //
//        _Table *table = _in_resize ? &_resize_table : &_main_table;
//        _Node n = _Node(computed_hash, k, v);
//        hash_t h = computed_hash % table._buckets_size;
//        table._buckets[h]._chain.insertFront(n);
//        table._length++;
//        _stat.inserts++;
//        return no!V;
//    }
//
//    bool remove(K k) @nogc @safe {
//        bool removed;
//        removed = remove_from_table(&_main_table, k);
//        if ( removed ) {
//            _main_table._length--;
//            _stat.removes++;
//            return true;
//        }
//
//        if (! _in_resize ) {
//            return false;
//        }
//
//        removed = remove_from_table(&_resize_table, k);
//        if ( removed ) {
//            _resize_table._length--;
//            _stat.removes++;
//            return true;
//        }
//        return false;
//    }
//
//    Stat stat() @safe @nogc pure nothrow {
//        return _stat;
//    }
//}
//
//@safe unittest {
//    import std.stdio;
//    import std.experimental.logger;
//    globalLogLevel = LogLevel.info;
//
//    HashMap!(int, string) m;
//    bool ok;
//    auto u = m.put(1, "one");
//    assert(u.empty);
//    auto v = m.get(1);
//    assert(!v.empty && v == "one");
//    assert(1 in m);
//    v = m.get(2);
//    assert(v.empty);
//    assert(2 !in m);
//    // try to replace 
//    u = m.put(1, "not one");
//    assert(!u.empty);
//    assert(u == "one");
//    //m.clear();
//}
//
//@safe unittest {
//    import std.format, std.stdio;
//    import std.experimental.logger;
//    globalLogLevel = LogLevel.info;
//
//    // resize
//    HashMap!(int, string) m;
//    bool ok, inserted;
//    foreach(i; 0..128) {
//        m.put(i, "%d".format(i));
//    }
//    auto stat = m.stat;
//    assert(stat.resizes == 1);
//    assert(stat.puts == 128);
//    auto v = m.get(1);
//    stat = m.stat;
//    assert(stat.gets == 1);
//    assert(stat.hits == 1);
//    m.put(1, "11");
//    stat = m.stat;
//    assert(stat.puts - stat.inserts == 1);
//    m.clear();
//    stat = m.stat;
//    assert(m.stat.gets == 0);
//}

@safe unittest {
    class A {
        int v;
        //override bool opEquals(Object o) const @safe @nogc nothrow {
        //    auto other = cast(A)o;
        //    return v == other.v;
        //}
        bool opEquals(const A o) pure const @safe @nogc nothrow {
            return v == o.v;
        }
        hash_t hash() const @safe @nogc nothrow {
            return hash_function(v);
        }
        override hash_t toHash() const @safe @nogc {
            return hash_function(v);
        }
        this(int v)
        {
            this.v = v;
        }
        override string toString() const
        {
            import std.format;
            return "A(%d)".format(v);
        }
    }
    globalLogLevel = LogLevel.info;
    auto x = new A(1);
    auto y = new A(2);
    OAHashMap!(A, string) dict;
    dict.put(x, "x");
    dict.put(y, "y");
    
}

///
/// Return true if it is worth to store values inline in hash table
/// V footprint should be small enough
///
package bool SmallValueFootprint(V)() {
    import std.traits;
    static if (
           isNumeric!V
        || isSomeString!V
        || isSomeChar!V
        || isPointer!V )
    {
            return true;
    }
    else static if (
           is(V == struct) && V.sizeof <= (void*).sizeof )
    {
            return true;
    }
    else static if (
            is(V == class ) && __traits(classInstanceSize, V) <= (void*).sizeof)
    {
        return true;
    }
    else
        return false;
}

private bool keyEquals(K)(const K a, const K b)
{
    static if ( is(K==class) )
    {
        if (a is b)
        {
            return true;
        }
        if (a is null || b is null)
        {
            return false;
        }
        return a.opEquals(b);
    }
    else
    {
        return a == b;
    }
}
/*
dub run -b release --compiler ldc2
Running ./cachetools 
AA!(int,int)    [137 ms, 348 μs, and 6 hnsecs]
OA!(int,int)    [77 ms, 913 μs, and 1 hnsec]
OA!(int,int) GC [80 ms, 571 μs, and 3 hnsecs]
---
AA large        [122 ms and 157 μs]
OA large        [177 ms, 167 μs, and 4 hnsecs]
OA large GC     [125 ms, 771 μs, and 8 hnsecs]
---
AA largeClass   [183 ms, 366 μs, and 3 hnsecs]
OA largeClass   [124 ms, 617 μs, and 3 hnsecs]
OA largeClassGC [106 ms, 407 μs, and 7 hnsecs]
---
*/

struct OAHashMap(K, V, Allocator = Mallocator) {

    enum initial_buckets_num = 32;
    enum grow_factor = 2;
    enum inlineValues = true;//SmallValueFootprint!V();
    enum InlineValueOrClass = inlineValues || is(V==class);
    enum overload_threshold = 0.75;
    enum deleted_threshold = 0.2;

    private {
        alias   allocator = Allocator.instance;
        static if (hash_t.sizeof == 8)
        {
            enum    EMPTY_HASH =     0x00_00_00_00_00_00_00_00;
            enum    DELETED_HASH =   0x10_00_00_00_00_00_00_00;
            enum    ALLOCATED_HASH = 0x20_00_00_00_00_00_00_00;
            enum    TYPE_MASK =      0xF0_00_00_00_00_00_00_00;
            enum    HASH_MASK =      0x0F_FF_FF_FF_FF_FF_FF_FF;
        }
        else static if (hash_t.sizeof == 4)
        {
            enum    EMPTY_HASH =     0x00_00_00_00;
            enum    DELETED_HASH =   0x10_00_00_00;
            enum    ALLOCATED_HASH = 0x20_00_00_00;
            enum    TYPE_MASK =      0xF0_00_00_00;
            enum    HASH_MASK =      0x0F_FF_FF_FF;
        }

        struct  _Bucket {
            hash_t  hash;
            K       key;
            static if (InlineValueOrClass)
            {
                V   value;
            }
            else
            {
                V*  value_ptr;
            }

            string toString() const {
                import std.format;
                static if (InlineValueOrClass) {
                    return "%s, hash: %0x,key: %s, value: %s".format(
                        [EMPTY_HASH:"free", DELETED_HASH:"deleted", ALLOCATED_HASH:"allocated"][cast(long   )(hash & TYPE_MASK)],
                        hash, key, value);
                } else {
                    return "%s, hash: %0x, key: %s, value: %s".format(
                        [EMPTY_HASH:"free", DELETED_HASH:"deleted", ALLOCATED_HASH:"allocated"][cast(long)(hash & TYPE_MASK)],
                        hash, key,
                        value_ptr !is null?  format("%s", *value_ptr) : "-");
                }
            }
        }
        int         _buckets_num;
        int         _mask;
        _Bucket[]   _buckets;
        int         _allocated;
        int         _deleted;
        int         _empty;
    }

    ~this() @safe {
        if ( _buckets_num > 0 ) {
            static if ( !InlineValueOrClass ) {
                for(int i=0;i<_buckets_num;i++) {
                    auto t = _buckets[i].hash;
                    if ( t <= DELETED_HASH ) {
                        continue;
                    }
                    (() @trusted {dispose(allocator, _buckets[i].value_ptr);})();
                }
            }
            (() @trusted {
                GC.removeRange(_buckets.ptr);
                dispose(allocator, _buckets);
            })();
        }
    }
    invariant {
        assert(_allocated>=0 && _deleted>=0 && _empty >= 0);
        assert(_allocated + _deleted + _empty == _buckets_num, "a:%s + d:%s + e:%s != total: %s".format(_allocated, _deleted,  _empty, _buckets_num));
    }
    ///
    /// Find any unallocated bucket starting from start_index (inclusive)
    /// Returns index on success or hash_t.max on fail
    ///
    package hash_t findEmptyIndex(const hash_t start_index) pure const @safe @nogc {
        hash_t index = start_index;

        do {
            () @nogc {debug(cachetools) tracef("test index %d for non-ALLOCATED", index);}();
            if ( _buckets[index].hash < ALLOCATED_HASH )
            {
                return index;
            }
            index = (index + 1) & _mask;
        } while(index != start_index);
        return hash_t.max;
    }
    ///
    /// Find allocated bucket for given key and computed hash starting from start_index
    /// Returns: index if bucket found or hash_t.max otherwise
    ///
    /// Inherits @nogc and from K opEquals()
    ///
    package hash_t findEntryIndex(const hash_t start_index, const hash_t hash, in K key) pure const @safe
    in
    {
        assert(hash < DELETED_HASH);
        assert(start_index < _buckets_num);
    }
    do {
        hash_t index = start_index;

        do {
            immutable h = _buckets[index].hash;

            () @nogc @trusted {debug(cachetools) tracef("test entry index %d (%s) for key %s", index, _buckets[index].toString, key);}();

            if ( h == EMPTY_HASH ) {
                break;
            }

            if ( h >= ALLOCATED_HASH && (h & HASH_MASK) == hash && keyEquals(_buckets[index].key, key) ) {
                //() @nogc {debug(cachetools) tracef("test entry index %d for key %s - success", index, key);}();
                return index;
            }
            index = (index + 1) & _mask;
        } while(index != start_index);
        return hash_t.max;
    }

    ///
    /// Find place where we can insert(first DELETED or EMPTY bucket) or update existent (ALLOCATED)
    /// bucket for key k and precomputed hash starting from start_index
    ///
    ///
    /// Inherits @nogc from K opEquals()
    ///
    package hash_t findUpdateIndex(const hash_t start_index, const hash_t computed_hash, in K key) pure const @safe
    in 
    {
        assert(computed_hash < DELETED_HASH);
        assert(start_index < _buckets_num);
    }
    do {
        hash_t index = start_index;

        do {
            immutable h = _buckets[index].hash;

            () @nogc @trusted {debug(cachetools) tracef("test update index %d (%s) for key %s", index, _buckets[index], key);}();

            if ( h <= DELETED_HASH ) { // empty or deleted
                () @nogc @trusted {debug(cachetools) tracef("test update index %d (%s) for key %s - success", index, _buckets[index], key);}();
                return index;
            }
            assert((h & TYPE_MASK) == ALLOCATED_HASH);
            if ( (h & HASH_MASK) == computed_hash && keyEquals(_buckets[index].key, key) ) 
            {
                () @nogc @trusted {debug(cachetools) tracef("test update index %d (%s) for key %s - success", index, _buckets[index], key);}();
                return index;
            }
            index = (index + 1) & _mask;
        } while(index != start_index);
        return hash_t.max;
    }
    ///
    /// Find unallocated entry in the buckets slice
    /// We use this function during resize() only.
    ///
    package long findEmptyIndexExtended(const hash_t start_index, in ref _Bucket[] buckets, int new_mask) pure const @safe @nogc
    in
    {
        assert(start_index < buckets.length);
    }
    do
    {
        hash_t index = start_index;

        do {
            immutable t = buckets[index].hash;

            () @nogc @trusted {debug(cachetools) tracef("test empty index %d (%s)", 
                index, buckets[index]);}();
            
            if ( t <= DELETED_HASH ) // empty or deleted
            {
                return index;
            }

            index = (index + 1) & new_mask;
        } while(index != start_index);
        return hash_t.max;
    }

    V* opBinaryRight(string op)(in K k) @safe if (op == "in") {

        if ( _buckets_num == 0 ) return null;

        immutable computed_hash = hash_function(k) & HASH_MASK;
        immutable start_index = computed_hash & _mask;
        immutable lookup_index = findEntryIndex(start_index, computed_hash, k);
        if ( lookup_index == hash_t.max) {
            return null;
        }
        static if ( InlineValueOrClass )
        {
            return &_buckets[lookup_index].value;
        }
        else
        {
            return _buckets[lookup_index].value_ptr;
        }
    }

    bool tooMuchDeleted() pure const @safe @nogc {
        //
        // _deleted > _buckets_num / 8
        //
        return _deleted << 3 > _buckets_num;
    }

    bool tooHighLoad() pure const @safe @nogc {
        //
        // _allocated/_buckets_num > 0.8
        // 5 * allocated > 4 * buckets_num
        //
        return _allocated + (_allocated << 2) > _buckets_num << 2;
    }

    void doResize(int dest) @safe {
        immutable _new_buckets_num = dest;
        immutable _new_mask = dest - 1;
        _Bucket[] _new_buckets = makeArray!(_Bucket)(allocator, _new_buckets_num);
        () @trusted {GC.addRange(_new_buckets.ptr, _new_buckets_num * _Bucket.sizeof);}();
        // iterate over entries
        () @nogc {debug(cachetools) trace("start resizing");}();
        () @nogc {debug(cachetools) tracef("start resizing: old loadfactor: %s", (1.0*_allocated) / _buckets_num);}();
        for(int i=0;i<_buckets_num;i++) {
            immutable hash_t h = _buckets[i].hash;
            if ( h < ALLOCATED_HASH ) { // empty or deleted
                continue;
            }

            immutable hash_t start_index = h & _new_mask;
            immutable new_position = findEmptyIndexExtended(start_index, _new_buckets, _new_mask);
            () @nogc {debug(cachetools) tracef("old hash: %0x, old pos: %d, new_pos: %d", h, i, new_position);}();
            assert( new_position >= 0 );
            assert( _new_buckets[cast(hash_t)new_position].hash  == EMPTY_HASH );

            _new_buckets[cast(hash_t)new_position] = _buckets[i];
        }
        (() @trusted {
            GC.removeRange(_buckets.ptr);
            dispose(allocator, _buckets);
        })();
        _buckets = _new_buckets;
        _buckets_num = _new_buckets_num;
        assert(_popcnt(_buckets_num) == 1, "Buckets number must be power of 2");
        _mask = _buckets_num - 1;
        _deleted = 0;
        _empty = _buckets_num - _allocated;
        () @nogc {debug(cachetools) trace("resizing done");}();
        () @nogc {debug(cachetools) tracef("resizing done: new loadfactor: %s", (1.0*_allocated) / _buckets_num);}();
    }

    //alias put = putOld;

    ///
    /// put pair (k,v) into hash.
    /// it must be @safe, it inherits @nogc properties from K and V
    /// It can resize hashtable it is overloaded or has too much deleted entries
    ///
    bool put(K k, V v) @safe {
        if ( !_buckets_num ) {
            _buckets_num = _empty = initial_buckets_num;
            assert(_popcnt(_buckets_num) == 1, "Buckets number must be power of 2");
            _mask = _buckets_num - 1;
            _buckets = makeArray!(_Bucket)(allocator, _buckets_num);
            () @trusted {GC.addRange(_buckets.ptr, _buckets_num * _Bucket.sizeof);}();
        }

        () @nogc @trusted {debug(cachetools) tracef("put k: %s, v: %s", k,v);}();

        if ( tooHighLoad ) {
            doResize(grow_factor * _buckets_num);
        }


        immutable computed_hash = hash_function(k) & HASH_MASK;
        immutable start_index = computed_hash & _mask;
        immutable placement_index = findUpdateIndex(start_index, computed_hash, k);
        assert(placement_index >= 0);
        immutable h = _buckets[placement_index].hash;

        () @nogc @trusted {debug(cachetools) tracef("start_index: %d, placement_index: %d", start_index, placement_index);}();

        static if ( InlineValueOrClass )
        {
            () @nogc @trusted {debug(cachetools) tracef("place inline buckets[%d] '%s'='%s'", placement_index, k, v);}();
            _buckets[placement_index].value = v;
        }
        else
        {
            () @nogc @trusted {debug(cachetools) tracef("place with allocation buckets[%d] '%s'='%s'", placement_index, k, v);}();
            if ( (_buckets[placement_index].hash & TYPE_MASK) == ALLOCATED_HASH )
            {
                // we just replace what we already allocated
                *(_buckets[placement_index].value_ptr) = v;
            }
            else
            {
                auto p = make!(V)(allocator);
                *p = v;
                _buckets[placement_index].value_ptr = p;
            }
        }
        if ( h < ALLOCATED_HASH )
        {
            _allocated++;
            _empty--;
        }
        _buckets[placement_index].hash = computed_hash | ALLOCATED_HASH;
        _buckets[placement_index].key = k;
        return true;
    }

    //bool putRobinHood(K k, V v) @safe {
    //    //
    //    // RobinHood hashing
    //    //
    //
    //    import std.algorithm.mutation: swap;
    //    if ( !_buckets_num ) {
    //        _buckets_num = _empty = initial_buckets_num;
    //        _buckets = makeArray!(_Bucket)(allocator, _buckets_num);
    //    }
    //
    //    () @nogc @trusted {debug(cachetools) tracef("robinhood put k: %s, v: %s", k,v);}();
    //
    //    if ( tooHighLoad ) {
    //        doResize(2*_buckets_num);
    //    }
    //
    //    if ( tooMuchDeleted ) {
    //        doResize(_buckets_num);
    //    }
    //
    //    auto computed_hash = hash_function(k);
    //    long start_index = computed_hash % _buckets_num;
    //    long placement_index = start_index;
    //
    //    static if (!(inlineValues || is(V==class)) ) {
    //        auto value_ptr = make!(V)(allocator);
    //        *value_ptr = v;
    //    }
    //
    //    do {
    //        () @nogc @trusted {debug(cachetools) tracef("test bucket[%d] = %s", placement_index, _buckets[placement_index]);}();
    //
    //        immutable b_type = _buckets[placement_index].type;
    //        if ( b_type == EMPTY ) {
    //            break;
    //        }
    //        immutable b_hash = _buckets[placement_index].hash;
    //        auto b_key = _buckets[placement_index].key;
    //        if ( b_type == ALLOCATED && computed_hash == b_hash && k == b_key ) {
    //            break;
    //        }
    //
    //        immutable b_ideal_index = b_hash % _buckets_num;
    //        immutable his_distance = (placement_index - b_ideal_index) % _buckets_num;
    //        immutable my_distance =   (placement_index - start_index) % _buckets_num;
    //
    //        () @nogc @trusted {debug(cachetools) tracef("put k: %s, v: %s, his_distance: %d, my_distance: %d", k, v, his_distance, my_distance);}();
    //
    //        if ( my_distance > his_distance )
    //        {
    //            // do swap
    //            () @nogc @trusted {debug(cachetools) tracef("swapping key %s with key %s", k, b_key);}();
    //
    //            swap(k, _buckets[placement_index].key);
    //            swap(computed_hash, _buckets[placement_index].hash);
    //            //swap(start_index, b_ideal_index);
    //            static if ( inlineValues || is(V==class) ) {
    //                swap(v, _buckets[placement_index].value);
    //            }
    //            else
    //            {
    //                swap(value_ptr, _buckets[placement_index].value_ptr);
    //            }
    //            () @nogc @trusted {debug(cachetools) tracef("after swap bucket[%d] = %s", placement_index, _buckets[placement_index]);}();
    //        }
    //        placement_index = ++placement_index % _buckets_num;
    //        assert(placement_index != start_index, "table full");
    //    } while (true);
    //
    //    //long placement_index = findUpdateIndex(start_index, computed_hash, k);
    //    assert(placement_index >= 0);
    //
    //    () @nogc @trusted {debug(cachetools) tracef("key: %s, start_index: %d, placement_index: %d", k, start_index, placement_index);}();
    //
    //    _buckets[placement_index].type = ALLOCATED;
    //    _buckets[placement_index].hash = computed_hash;
    //    _buckets[placement_index].key = k;
    //    static if ( inlineValues || is(V==class) )
    //    {
    //        () @nogc @trusted {debug(cachetools) tracef("place inline buckets[%d] '%s'='%s'", placement_index, k, v);}();
    //        _buckets[placement_index].value = v;
    //    }
    //    else
    //    {
    //        () @nogc @trusted {debug(cachetools) tracef("place with allocation buckets[%d] '%s'='%s'", placement_index, k, v);}();
    //        auto p = make!(V)(allocator);
    //        *p = v;
    //        _buckets[placement_index].value_ptr = p;
    //    }
    //    _allocated++;
    //    _empty--;
    //    return true;
    //}

    bool remove(K k) @safe {
        import std.stdio;
        ////writefln("remove %s, deleted: %s", k, _deleted);
        if ( tooMuchDeleted ) {
            // do not shrink, just compact table
            doResize(_buckets_num);
        }


        () @nogc @trusted {debug(cachetools) tracef("remove k: %s", k);}();

        immutable computed_hash = hash_function(k) & HASH_MASK;
        immutable start_index = computed_hash & _mask;
        immutable lookup_index = findEntryIndex(start_index, computed_hash, k);
        if ( lookup_index == hash_t.max ) {
            // nothing to remove
            return false;
        }

        assert((_buckets[lookup_index].hash & TYPE_MASK) == ALLOCATED_HASH, "tried to remove non allocated bucket");

        static if ( InlineValueOrClass )
        {
            // what we have to do with removed values XXX?
        }
        else
        {
            // what we have to do with removed values XXX?
            // free space
            (() @trusted {dispose(allocator, _buckets[lookup_index].value_ptr);})();
            _buckets[lookup_index].value_ptr = null;
        }

        _allocated--;
        immutable next_index = (lookup_index + 1) & _mask;
        // if next bucket is EMPTY, then we can convert all DELETED buckets down staring from current to EMPTY buckets
        if ( _buckets[next_index].hash == EMPTY_HASH )
        {
            _empty++;
            _buckets[lookup_index].hash = EMPTY_HASH;
            auto free_index = (lookup_index - 1) & _mask;
            while (free_index != lookup_index) {
                if ( _buckets[free_index].hash != DELETED_HASH ) {
                    break;
                }
                _buckets[free_index].hash = EMPTY_HASH;
                _deleted--;
                _empty++;
                free_index = (free_index - 1) & _mask;
            }
            assert(free_index != lookup_index, "table full of deleted buckets?");
        }
        else
        {
            _buckets[lookup_index].hash = DELETED_HASH;
            _deleted++;
        }
        return true;
    }

    auto length() const pure nothrow @nogc @safe
    {
        return _allocated;
    }

    auto size() const pure nothrow @nogc @safe
    {
        return _buckets_num;
    }

    auto byKey() pure @safe @nogc
    {
        struct _kvRange {
            int         _pos;
            ulong       _buckets_num;
            _Bucket[]   _buckets;
            this(_Bucket[] _b)
            {
                _buckets = _b;
                _buckets_num = _b.length;
                _pos = 0;
                while( _pos < _buckets_num  && _buckets[_pos].hash < ALLOCATED_HASH )
                {
                    _pos++;
                }
            }
            bool empty() const pure nothrow @safe @nogc
            {
                return _pos == _buckets_num;
            }
            K front()
            {
                return _buckets[_pos].key;
            }
            void popFront() pure nothrow @safe @nogc
            {
                _pos++;
                while( _pos < _buckets_num && _buckets[_pos].hash <  ALLOCATED_HASH )
                {
                    _pos++;
                }
            }
        }
        return _kvRange(_buckets);
    }

    auto byValue() pure
    {
        struct _kvRange {
            int         _pos;
            ulong       _buckets_num;
            _Bucket[]   _buckets;
            this(_Bucket[] _b)
            {
                _buckets = _b;
                _buckets_num = _b.length;
                _pos = 0;
                while( _pos < _buckets_num  && _buckets[_pos].hash < ALLOCATED_HASH )
                {
                    _pos++;
                }
            }
            bool empty() const pure nothrow @safe @nogc
            {
                return _pos == _buckets_num;
            }
            V front()
            {
                static if (inlineValues)
                {
                    return _buckets[_pos].value;
                }
                else
                {
                    return *(_buckets[_pos].value_ptr);
                }
            }
            void popFront() pure nothrow @safe @nogc
            {
                _pos++;
                while( _pos < _buckets_num && _buckets[_pos].hash < ALLOCATED_HASH )
                {
                    _pos++;
                }
            }
        }
        return _kvRange(_buckets);
    }

    auto byPair() pure
    {
        import std.typecons;

        struct _kvRange {
            int         _pos;
            ulong       _buckets_num;
            _Bucket[]   _buckets;
            this(_Bucket[] _b)
            {
                _buckets = _b;
                _buckets_num = _b.length;
                _pos = 0;
                while( _pos < _buckets_num  && _buckets[_pos].hash < ALLOCATED_HASH )
                {
                    _pos++;
                }
            }
            bool empty() const pure nothrow @safe @nogc
            {
                return _pos == _buckets_num;
            }
            auto front() @safe
            {
                static if (inlineValues)
                {
                    return Tuple!(K, "key", V, "value")(_buckets[_pos].key, _buckets[_pos].value);
                }
                else
                {
                    return Tuple!(K, "key", V, "value")(_buckets[_pos].key, *(_buckets[_pos].value_ptr));
                }
            }
            void popFront() pure nothrow @safe @nogc
            {
                _pos++;
                while( _pos < _buckets_num && _buckets[_pos].hash < ALLOCATED_HASH )
                {
                    _pos++;
                }
            }
        }
        return _kvRange(_buckets);
    }
}

@safe unittest {
    globalLogLevel = LogLevel.info;
    () @nogc {
        OAHashMap!(int, int) int2int;
        foreach(i; 1..5) {
            int2int.put(i,i);
        }
        int2int.put(33,33); // <- follow key 1, move key 2 on pos 3
        assert(1 in int2int, "1 not in hash");
        assert(2 in int2int, "2 not in hash");
        assert(1 in int2int, "3 not in hash");
        assert(4 in int2int, "4 not in hash");
        assert(33 in int2int, "33 not in hash");
        int2int.remove(33);
        int2int.put(2,2); // <- must replace key 2 on pos 3
        assert(2 in int2int, "2 not in hash");
    }();
    () @nogc {
        struct LargeStruct {
            ulong a;
            ulong b;
        }
        OAHashMap!(int, LargeStruct) int2ls;
        foreach(i; 1..5) {
            int2ls.put(i,LargeStruct(i,i));
        }
        int2ls.put(33,LargeStruct(33,33)); // <- follow key 1, move key 2 on pos 3
        assert(1 in int2ls, "1 not in hash");
        assert(2 in int2ls, "2 not in hash");
        assert(3 in int2ls, "3 not in hash");
        assert(4 in int2ls, "4 not in hash");
        assert(33 in int2ls, "33 not in hash");
        int2ls.remove(33);
        int2ls.put(2,LargeStruct(2,2)); // <- must replace key 2 on pos 3
        assert(2 in int2ls, "2 not in hash");
    }();
}

@safe unittest {
    globalLogLevel = LogLevel.info;
    () @nogc {
        assert(SmallValueFootprint!int());
        assert(SmallValueFootprint!double());
        struct SmallStruct {
            ulong a;
        }
        //assert(SmallValueFootprint!SmallStruct);
        struct LargeStruct {
            ulong a;
            ulong b;
        }
        assert(!SmallValueFootprint!LargeStruct);
        class SmallClass {
            ulong a;
        }
        //assert(!SmallValueFootprint!SmallClass);

        OAHashMap!(int, string) int2string;
        auto u = int2string.put(1, "one");
        {
            auto v = 1 in int2string;
            assert(v !is null);
            assert(*v == "one");
        }
        assert(2 !in int2string);
        u = int2string.put(32+1, "33");
        assert(33 in int2string);
        assert(int2string.remove(33));
        assert(!int2string.remove(33));
        
        OAHashMap!(int, LargeStruct) int2LagreStruct;
        u = int2LagreStruct.put(1, LargeStruct(1,2));
        {
            auto v = 1 in int2LagreStruct;
            assert(v !is null);
            assert(*v == LargeStruct(1, 2));
        }
    }();

    globalLogLevel = LogLevel.info;
}

@safe unittest {
    import std.experimental.allocator.gc_allocator;
    globalLogLevel = LogLevel.info;
    static int i;
    () @safe @nogc {
        struct LargeStruct {
            ulong a;
            ulong b;
            ~this() @safe @nogc {
                i++;
            }
        }
        OAHashMap!(int, LargeStruct) int2LagreStruct;
        int2LagreStruct.put(1, LargeStruct(1,2));
    }();
    globalLogLevel = LogLevel.info;
}

@safe unittest
{
    import std.typecons;
    alias K = Tuple!(int, int);
    alias V = int;
    OAHashMap!(K,V) h;
    K k0 = K(0,1);
    V v0 = 1;
    h.put(k0, v0);
    int *v = k0 in h;
    assert(v);
    assert(*v == 1);
    
}

@safe unittest
{
    class c {
        int a;
        this(int a)
        {
            this.a = a;
        }
        override hash_t toHash() const pure @nogc @safe
        {
            return hash_function(a);
        }
        bool opEquals(const c other) pure const @safe @nogc
        {
            return this is other || this.a == other.a;
        }
    }
    alias K = c;
    alias V = int;
    OAHashMap!(K,V) h;
    K k0 = new c(0);
    V v0 = 1;
    h.put(k0, v0);
    int *v = k0 in h;
    assert(v);
    assert(*v == 1);

}

/// Test if we can work with non-@nogc opEquals for class-key.
/// opEquals anyway must be non-@system.
@safe unittest
{
    class c {
        int a;
        this(int a)
        {
            this.a = a;
        }
        override hash_t toHash() const pure @safe
        {
            int[] _ = [1, 2, 3]; // this cause GC
            return hash_function(a);
        }

        bool opEquals(const c other) const pure @safe
        {
            auto _ = [1,2,3]; // this cause GC
            return this is other || this.a == other.a;
        }
    }
    alias K = c;
    alias V = int;
    OAHashMap!(K,V) h;
    K k0 = new c(0);
    V v0 = 1;
    h.put(k0, v0);
    int *v = k0 in h;
    assert(v);
    assert(*v == 1);

}

@safe unittest
{
    import std.algorithm;
    import std.array;
    import std.stdio;

    OAHashMap!(int, string) m;
    m.put(1,  "one");
    m.put(2,  "two");
    m.put(10, "ten");
    assert(equal(m.byKey.array.sort, [1,2,10]));
    assert(equal(m.byValue.array.sort, ["one", "ten", "two"]));
    assert(equal(
        m.byPair.map!"tuple(a.key, a.value)".array.sort, 
        [tuple(1, "one"), tuple(2, "two"), tuple(10, "ten")]
    ));
    m.remove(1);
    m.remove(10);
    assert(equal(
    m.byPair.map!"tuple(a.key, a.value)".array.sort,
        [tuple(2, "two")]
    ));
    m.remove(2);
    assert(m.byPair.map!"tuple(a.key, a.value)".array.sort.length() == 0);
    m.remove(2);
    assert(m.byPair.map!"tuple(a.key, a.value)".array.sort.length() == 0);
}

unittest {
    import std.random;
    import std.array;
    import std.algorithm;
    import std.stdio;

    enum iterations = 400_000;

    globalLogLevel = LogLevel.info;

    OAHashMap!(int, int) HashMap;
    int[int]             AA;

    auto rnd = Random(unpredictableSeed);

    foreach(i;0..iterations) {
        int k = uniform(0, iterations, rnd);
        HashMap.put(k, i);
        AA[k] = i;
    }
    //writeln(AA.keys().sort());
    //writeln(HashMap.byKey().array.sort());
    assert(equal(AA.keys().sort(), HashMap.byKey().array.sort()));
    assert(equal(AA.values().sort(), HashMap.byValue().array.sort()));
    //assert(equal(AA.length, HashMap.length));
}
