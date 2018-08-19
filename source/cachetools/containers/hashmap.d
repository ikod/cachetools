module cachetools.containers.hashmap;

import std.traits;
import optional;

private import stdx.allocator;
private import stdx.allocator.mallocator : Mallocator;

private import cachetools.hash;
private import cachetools.containers.slist;

/// write to stdout
static void log(A...)(string fmt, A args) @nogc @trusted {
    import core.stdc.stdio : printf;
    printf(fmt.ptr, args);
}

// K (key type) must be of value type without references.

struct HashMap(K, V, Allocator = Mallocator) {
    /// Various statistics collector
    struct Stat {
        ulong   gets;             /// # of get() calls
        ulong   puts;             /// # of put() calls
        ulong   hits;
        ulong   inserts;
        ulong   removes;
        ulong   resizes;
        size_t  key_space;
        size_t  value_space;
    }

    private {
        // resize load_factor.
        // Trigger for resize.
        // if load factor (num of elements in hash table divide hash rows) reach resize_load_factor then we 
        // start resize process
        enum    resize_load_factor = 3.0;
        // resize_step.
        // during resize we have to transfer all items from main table to 'resize' table 
        // (using new hash rows and hash calculatons) and then use this new table as main.
        // We do not transfer all items at once as it can take too much time. We transfer
        // 'resize_step' items on each iteration while there are any items in main table.
        enum    resize_step = 10;

        alias   allocator = Allocator.instance;
        alias   NodeT = _Node;
        struct _Node {
            // node of the chain in bucket
            hash_t  hash;
            K       key;
            V       value;
        }
        struct _Bucket {
            // hash bucket 
            SList!_Node _chain;
        }
        struct _Table {
            ulong     _length;          // entries in table
            ulong     _buckets_size;    // buckets in table
            _Bucket[] _buckets;

            float load_factor() const pure @safe @nogc nothrow {
                if ( _length == 0 || _buckets_size == 0 ) {
                    return 0.0;
                }
                return float(_length)/_buckets_size;
            }

            bool overloaded() const @safe @nogc nothrow pure {
                return load_factor() > resize_load_factor;
            }
        }
        bool    _in_resize;
        _Table  _main_table;
        _Table  _resize_table;
        Stat    _stat;
    }

    ~this() @safe @nogc {
        clear();
    }

    invariant {
        assert(_in_resize ? _resize_table._buckets_size > 0 : _resize_table._buckets_size == 0);
    }
    ///
    /// We detected that it's time to resize.
    /// 1. calculate new buckets_size
    /// 2. allocate new buckets array
    ///
    private void start_resize() @nogc @safe {
        debug(cachetools) log("start resize from %d\n", _main_table._buckets_size);
        _stat.resizes++;
        _in_resize = true;
        _resize_table._buckets_size = _main_table._buckets_size * 2;
        assert(_resize_table._buckets is null);
        _resize_table._buckets = makeArray!(_Bucket)(allocator, _resize_table._buckets_size);
    }

    private void do_resize_step() @nogc @safe {
        assert(_in_resize);
        size_t bucket_index = 0;
        _Bucket* b = &_main_table._buckets[bucket_index];
        for(int i; i < resize_step && _main_table._length > 0; i++) {
            debug(cachetools) log("resize_step\n");
            while ( b._chain.length == 0 ) {
                debug(cachetools) log("step to next bucket from %d\n", bucket_index);
                bucket_index++;
                if ( bucket_index >= _main_table._buckets_size ) {
                    assert(_main_table._length == 0);
                    stop_resize();
                    debug(cachetools) log("done\n");
                    return;
                }
                b = &_main_table._buckets[bucket_index];
            }
            debug(cachetools) log("bucket length = %d\n", b._chain.length);
            auto n = b._chain.front;
            b._chain.popFront;
            _main_table._length--;
            auto k = n.key;
            auto v = n.value;
            auto computed_hash = n.hash;
            debug(cachetools) log("move key %d\n", k);
            _Table *table = &_resize_table;
            _Node nn = _Node(computed_hash, k, v);
            hash_t h = computed_hash % table._buckets_size;
            table._buckets[h]._chain.insertFront(nn);
            table._length++;
        }
        debug(cachetools) log("resize_step done\n");
        if ( _main_table._length == 0 ) {
            stop_resize();
        }
    }

    ///
    /// All elements transfered to 'resize' table.
    /// free anything from main table and 'swap' content of main and resize tables
    /// 
    private void stop_resize() @nogc @safe {
        assert(_in_resize);
        assert(_main_table._length == 0);
        debug(cachetools) log("stop resize\n");
        _in_resize = false;
        // free old buckets array in main table
        (() @trusted {dispose(allocator, _main_table._buckets);})();
        // transfer everything from resize table to main table
        _main_table._length = _resize_table._length;
        _main_table._buckets = _resize_table._buckets;
        // initialize resize_table
        _main_table._buckets_size = _resize_table._buckets_size;
        _resize_table = _Table.init;
    }

    ulong length() const pure @nogc @safe {
        return _main_table._length + _resize_table._length;
    }

    void clear() @nogc @safe {
        clear_table(&_main_table);
        clear_table(&_resize_table);
        _stat = Stat.init;
    }

    private void clear_table(_Table* t) @nogc @safe nothrow {
        if ( t._buckets is null ) {
            return;
        }
        foreach(ref b; t._buckets) {
            b._chain.clear();
        }
        (() @trusted {dispose(allocator, t._buckets);})();
        t._length = 0;
        t._buckets = null;
        t._buckets_size = 0;
    }

    /// retturn true if removed from table, false otherwise
    private bool remove_from_table(_Table* t, K k) @nogc @safe nothrow {
        bool removed;
        immutable ulong computed_hash = hash_function(k);
        immutable ulong hash = computed_hash % t._buckets_size;

        auto bucket = &t._buckets[hash];
        removed = bucket._chain.remove_by_predicate((n) @nogc {return n.key==k;});
        return removed;
    }

    /// return true if updated in table
    private Optional!V update_in_table(_Table* t, K k, V v, hash_t computed_hash) @nogc @safe {
        immutable ulong hash = computed_hash % t._buckets_size;

        Optional!V r;
        auto chain = t._buckets[hash]._chain[];
        foreach(nodep; chain) {
            if (nodep.key == k) {
                // key found, replace. all done
                r = nodep.value;
                nodep.value = v;
                break;
            }
        }
        return r;
    }

    Optional!V get(K k) @safe @nogc {
        if ( _main_table._buckets_size == 0 ) {
            _main_table._buckets_size = 32;
            _main_table._buckets = makeArray!(_Bucket)(allocator, _main_table._buckets_size);
        }
        auto r = no!V;
        _stat.gets++;
        immutable ulong computed_hash = hash_function(k);
        _Table *t = &_main_table;
        ulong hash = computed_hash % t._buckets_size;
        auto chain = t._buckets[hash]._chain[];
        foreach(nodep; chain) {
            if (nodep.key == k) {
                _stat.hits++;
                r = nodep.value;
                break;
            }
        }
        if ( !_in_resize ) {
            return r;
        }
        //
        do_resize_step();
        //
        t = &_resize_table;
        hash = computed_hash % t._buckets_size;
        chain = t._buckets[hash]._chain[];
        foreach(nodep; chain) {
            if (nodep.key == k) {
                _stat.hits++;
                r = nodep.value;
                break;
            }
        }
        // notfound
        return r;
    }

    Optional!V put(K k, V v) @nogc @safe {
        if ( _main_table._buckets_size == 0 ) {
            _main_table._buckets_size = 32;
            _main_table._buckets = makeArray!(_Bucket)(allocator, _main_table._buckets_size);
        }

        _stat.puts++;

        if ( !_in_resize && _main_table.overloaded() ) {
            start_resize();
        }

        if ( _in_resize ) {
            do_resize_step();
        }
        
        immutable computed_hash = hash_function(k);


        auto u = update_in_table(&_main_table, k, v, computed_hash);

        if ( u != none ) {
            return u;
        }
        if ( _in_resize ) {
            u = update_in_table(&_resize_table, k, v, computed_hash);
        }

        if ( u != none ) {
            return u;
        }
        //
        // key is not in map.
        // insert it in proper table.
        //
        _Table *table = _in_resize ? &_resize_table : &_main_table;
        _Node n = _Node(computed_hash, k, v);
        hash_t h = computed_hash % table._buckets_size;
        table._buckets[h]._chain.insertFront(n);
        table._length++;
        _stat.inserts++;
        return no!V;
    }

    bool remove(K k) @nogc @safe nothrow {
        bool removed;
        removed = remove_from_table(&_main_table, k);
        if ( removed ) {
            _main_table._length--;
            _stat.removes++;
            return true;
        }

        if (! _in_resize ) {
            return false;
        }

        removed = remove_from_table(&_resize_table, k);
        if ( removed ) {
            _resize_table._length--;
            _stat.removes++;
            return true;
        }
        return false;
    }

    Stat stat() @safe @nogc pure nothrow {
        return _stat;
    }
}

@safe unittest {
    import std.stdio;
    import std.experimental.logger;
    globalLogLevel = LogLevel.info;

    HashMap!(int, string) m;
    bool ok;
    auto u = m.put(1, "one");
    assert(u.empty);
    auto v = m.get(1);
    assert(!v.empty && v == "one");
    v = m.get(2);
    assert(v.empty);
    // try to replace 
    u = m.put(1, "not one");
    assert(!u.empty);
    assert(u == "one");
    //m.clear();
}

@safe unittest {
    import std.format, std.stdio;
    import std.experimental.logger;
    globalLogLevel = LogLevel.info;

    // resize
    HashMap!(int, string) m;
    bool ok, inserted;
    foreach(i; 0..128) {
        m.put(i, "%d".format(i));
    }
    auto stat = m.stat;
    assert(stat.resizes == 1);
    assert(stat.puts == 128);
    auto v = m.get(1);
    stat = m.stat;
    assert(stat.gets == 1);
    assert(stat.hits == 1);
    m.put(1, "11");
    stat = m.stat;
    assert(stat.puts - stat.inserts == 1);
    m.clear();
    stat = m.stat;
    assert(m.stat.gets == 0);
}

@safe unittest {
    class A {
        int v;
        override bool opEquals(Object o) const @safe @nogc nothrow {
            auto other = cast(A)o;
            return v == other.v;
        }
        override hash_t toHash() const @safe @nogc nothrow {
            return 1;
        }
    }
    auto x = new A();
    auto y = new A();
    //HashMap!(A, string) dict;
}