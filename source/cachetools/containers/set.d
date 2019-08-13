///
module cachetools.containers.set;

import std.algorithm;
import std.range;

import cachetools.containers.hashmap;

///
/// create set from inoput range
///
auto set(R)(R r) if (isInputRange!R) {
    alias K = ElementType!R;
    Set!K result;
    r.each!(k => result.add(k));
    return result;
}

///
/// Set implemented as hash table
///
/// Inherits nogc and safety properties from key properties.
///
/// Implements next set ops
/// create - fill set from range
/// add - add item to set; O(1)
/// remove - remove item from set if present; O(1)
/// length - number of items in set; O(1)
/// join - join sets; O(N)
/// intersection - create intersection of two sets; O(N)
/// difference - create difference of two sets; O(N)
/// iterate - create iterator over set items;
/// in - if element presented in set; O(1)
struct Set(K) {
private:
        HashMap!(K, bool) _map;

public:

    ///
    void create(R)(R range) {
        _map.clear;
        range.each!(k => _map.put(k, true));
    }
    ///
    void add(K)(K k) {
        _map.put(k, true);
    }
    ///
    void remove(K)(K k) {
        _map.remove(k);
    }
    ///
    auto length() const {
        return _map.length;
    }
    ///
    void join(K)(Set!K other) {
        if ( other.length == 0 ) return;

        foreach(ref b; other._map._buckets) {
            if ( b.hash >= ALLOCATED_HASH ) 
                _map.put(b.key, true);
        }
    }
    ///
    auto intersection(K)(Set!K other) {
        Set!K result;

        if (other.length == 0 || this.length == 0 ) return result;

        if ( other.length < _map.length ) {
            foreach (ref bucket; other._map._buckets) {
                if ( bucket.hash >= ALLOCATED_HASH && bucket.key in _map )
                    result.add(bucket.key);
            }
        } else {
            foreach (ref bucket; _map._buckets) {
                if (bucket.hash >= ALLOCATED_HASH && bucket.key in other._map)
                    result.add(bucket.key);
            }
        }
        return result;
    }
    ///
    auto difference(K)(Set!K other) {
        Set!K result;
        if ( other.length == 0 ) return this;
        foreach (ref bucket; _map._buckets) {
            if (bucket.hash >= ALLOCATED_HASH && bucket.key !in other._map)
                result.add(bucket.key);
        }
        return result;
    }
    ///
    auto iterate() {
        return _map.byKey;
    }
    ///
    bool opBinaryRight(string op)(K k) inout if (op=="in") {
        return  k in _map?true:false;
    }
}


@safe @nogc unittest {
    import std.stdio;

    Set!string s;
    s.add("hello");
    assert(s.length == 1);
    assert(equal(s.iterate, only("hello")));
    s.remove("hello");
    assert(s.length == 0);
    s.remove("hello");
    assert(s.length == 0);

    s.create(only("hello", "hello", "world"));
    assert(s.length == 2);

    s.join(set(only("and", "bye")));
    assert(s.length == 4);

    auto other = set(only("and", "bye", "!"));
    auto cross0 = s.intersection(other);
    assert("bye" in cross0);
    assert("!"  !in cross0);
    auto cross1 = other.intersection(s);
    assert(cross0.length == cross1.length);
    assert("and" in cross0 && "and" in cross1);
    assert("bye" in cross0 && "bye" in cross1);

    auto nums = set(iota(10));
    auto someNums = nums.difference(set(only(1,2,3)));
    assert(0 in someNums);
    assert(1 !in someNums);

    bool f(const Set!string s) {
        return "yes" in s;
    }

    Set!string ss;
    ss.add("yes");
    f(ss);
    assert("yes" in ss);
}