module cachetools;

public import cachetools.fifo;
import cachetools.containers.hashmap;

public class Cache(K, V) {
    package {
        int _size;
    }
    this(int s = 64) @nogc @safe nothrow {
        _size = s;
    }
    void put(K k, V v) @nogc {}
    ulong length() const @nogc {assert(false);}
}

public struct PolicyCache(K, V, P) {
    P             policy;
    HashMap!(K, V)  map;
    ulong           size = 32;

    this(ulong s, P p) {
        policy = p;
        size = s;
    }
    
    ~this() {
        map.clear();
    }
    void put(K k, V v) @nogc @safe nothrow {
        bool inserted;
        map.put(k, v, inserted);
        if ( inserted )
        {
            policy.insert(k);
        }
        else 
        {
            policy.update(k);
        }
        if ( map.length() > size )
        {
            bool removed;
            K eviction_key = policy.evict();
            map.remove(eviction_key, removed);
            if ( removed ) {
                policy.remove(eviction_key);
            }
        }
    }
    V get(K k, out bool ok) @nogc @safe nothrow {
        return map.get(k, ok);
    }
    void remove(K k) {
        bool removed;
        map.remove(k, removed);
        if ( removed ) {
            policy.remove(k);
        }
    }
    auto length() const @safe @nogc {
        return map.length();
    }
}

auto makeCache(K, V, alias P)(ulong size) @safe @nogc {
    P!K policy;
    return PolicyCache!(K, V, P!K)(size, policy);
}

@safe unittest {
    import std.stdio;
    FIFOPolicy!int  policy;
    bool ok;
    string v;
    auto c = makeCache!(int, string, FIFOPolicy)(2);
    c.put(1, "one");
    c.put(2, "two");
    c.put(3, "three");
    v = c.get(1, ok);
    assert(!ok, "1 must be evicted");
    c.put(1, "one-two");
    c.put(1, "one-two-three");
    v = c.get(1, ok);
    assert(ok);
    assert(v == "one-two-three");
    v = c.get(2, ok); writefln("get 2 - %s(%s)", v, ok);
    assert(!ok, "2 must be evicted by 3 and 1");
    v = c.get(3, ok); writefln("get 3 - %s(%s)", v, ok);
    assert(ok);
    assert(v == "three");
    v = c.get(4, ok); writefln("get 4 - %s(%s)", v, ok);
    assert(!ok, "we never placed 4 into cache");
    import std.typecons;
    alias Tup = Tuple!(int, int);
    auto c2 = makeCache!(Tup, string, FIFOPolicy)(2);
    c2.put(Tup(1,1), "one");
    c2.put(Tup(2,2), "two");
    v = c2.get(Tup(1,1), ok); writefln("get (1,1) - %s(%s)", v, ok);
    assert(ok);
    assert(v == "one");
    v = c2.get(Tup(2,2), ok);
    assert(ok);
    assert(v == "two");
    v = c2.get(Tup(2,1), ok);
    assert(!ok, "(2,1) not in cache");
    c2.put(Tup(3,3), "three");
    v = c2.get(Tup(1,1), ok);
    assert(!ok, "(1,1) must be evicted");
    auto c3 = makeCache!(int, int, FIFOPolicy)(64);
    foreach(int i;0..1000) {
        c3.put(i, i);
    }
    assert(c3.length == 64);
    assert(c3.get(1000-64, ok)==1000-64 && ok);
    assert(c3.get(999, ok)==999 && ok);
}