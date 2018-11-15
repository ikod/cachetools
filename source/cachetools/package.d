module cachetools;

public import cachetools.interfaces;
public import cachetools.cache;
public import cachetools.containers.hashmap;

public struct Cache(K, V) {
    private {
        CachePolicy!(K,V)     _policy;
    }

    void policy(CachePolicy!(K,V) p) {
        _policy = p;
    }

    this(CachePolicy!(K,V) p) {
        _policy = p;
    }
    
    ~this() {
        _policy.clear();
    }

    void put(K k, V v) @nogc @safe {
        _policy.put(k, v);
    }

    Optional!V get(K k) @nogc @safe {
        return _policy.get(k);
    }

    bool remove(K k) {
        return _policy.remove(k);
    }

    auto length() const @safe @nogc {
        return _policy.length();
    }

}

auto makeCache(K, V)(CachePolicy!(K, V) p = null) @safe @nogc {
    auto c = Cache!(K, V)();
    if ( p !is null ) {
        c.policy = p;
    }
    return c;
}

@safe unittest {
    //import cachetools.cache;
    //import std.stdio;
    //import std.experimental.logger;
    
    //globalLogLevel = LogLevel.info;
    //
    //FIFOPolicy!(int, string)  policy = new FIFOPolicy!(int, string);
    //() @nogc {
    //    policy.maxLength(2);
    //    bool ok;
    //    Optional!string v;
    //    auto c = makeCache!(int, string)(policy);
    //    c.put(1, "one");
    //    c.put(2, "two");
    //    c.put(3, "three");
    //    v = c.get(1);
    //    assert(v.empty, "1 must be evicted");
    //    c.put(1, "one-two");
    //    c.put(1, "one-two-three");
    //    v = c.get(1);
    //    assert(!v.empty);
    //    assert(v == "one-two-three");
    //    v = c.get(2);
    //    assert(v.empty, "2 must be evicted by 3 and 1");
    //    v = c.get(3);
    //    assert(!v.empty);
    //    assert(v == "three");
    //    v = c.get(4);
    //    assert(v.empty, "we never placed 4 into cache");
    //}();
    //import std.typecons;
    //alias Tup = Tuple!(int, int);
    //auto p2 = new FIFOPolicy!(Tup, string);
    //() @nogc {
    //    p2.maxLength(2);
    //    auto c2 = makeCache!(Tup, string)(p2);
    //    c2.put(Tup(1,1), "one");
    //    c2.put(Tup(2,2), "two");
    //    auto v = c2.get(Tup(1,1));
    //    assert(!v.empty);
    //    assert(v == "one");
    //    //v = c2.get(Tup(2,2));
    //    //assert(!v.empty);
    //    //assert(v == "two");
    //    v = c2.get(Tup(2,1));
    //    assert(v.empty, "(2,1) not in cache");
    //    c2.put(Tup(3,3), "three");
    //    v = c2.get(Tup(2,2));
    //    assert(v.empty, "(2,2) must be evicted by second chance algorithm");
    //}();
    //
    //globalLogLevel = LogLevel.info;
    //auto p3 = new FIFOPolicy!(int, int);
    //p3.maxLength(64);
    //() @nogc {
    //    auto c3 = makeCache!(int, int)(p3);
    //    foreach(int i;0..1000) {
    //        c3.put(i, i);
    //    }
    //    assert(c3.length == 64);
    //    assert(c3.get(1000-64)==1000-64);
    //    assert(c3.get(999)==999);
    //}();
}