module cachetools.hash;

import std.traits;
import std.stdio;
import std.format;
import std.typecons;

ulong hash_function(T)(in T v) @nogc @trusted {
    //
    // XXX this must be changed to core.internal.hash.hashOf when it become @nogc
    // https://github.com/dlang/druntime/blob/master/src/core/internal/hash.d
    //
    static if ( isNumeric!T ) {
        return v;
    }
    else static if ( is(T == string) ) {
        hash_t h = 0xcbf29ce484222325;
        foreach (const ubyte c; cast(ubyte[]) v)
        {
            h ^= ((c - ' ') * 13);
            h *= 0x100000001b3;
        }
        return h;
    } else {
        const(ubyte)[] bytes = (() @trusted => (cast(const(ubyte)*)&v)[0 .. T.sizeof])();
        hash_t h = 0xcbf29ce484222325;
        foreach (const ubyte c; bytes)
        {
            h ^= ((c - ' ') * 13);
            h *= 0x100000001b3;
        }
        return h;
    }
}

//bool canUseToHash(T)() {
//    return __traits(compiles, {
//        hash_t getHash(U)(U u) @nogc @safe nothrow {
//            return u.toHash();
//        }
//        T v = T.init;
//        getHash(v);
//    });
//}
//
//bool canUseOpEquals(T)() if ( !is(T == class) ) {
//    return __traits(compiles, {
//        bool cmp(T a, T b) @safe @nogc {
//            return a == b;
//        }
//        T x = T.init, y = T.init;
//        cmp(x, y);
//    });
//}
//
//bool canUseOpEquals(T)() if ( is(T == class) ) {
//    return __traits(compiles, {
//        bool cmp(T a, T b) @safe @nogc {
//            return a.opEquals(b);
//        }
//        T x = T.init, y = T.init;
//        cmp(x, y);
//    });
//}
//
//void describe(T)() {
//    enum testHash = canUseToHash!T;
//    enum testEquals = canUseOpEquals!T;
//
//    writefln("%s: safeHash: %s, safeOpEquals: %s".format(T.stringof, testHash, testEquals));
//    static if (is(T == class)) {
//        writefln(" %s is class", T.stringof);
//    }
//    static if (is(T == struct)) {
//        writefln(" %s is struct", T.stringof);
//    }
//    writeln("---");
//}
//
/////
//bool canBeKey(T)() if (
//        is(T == string) || 
//        isIntegral!T
//    ) {
//    return true;
//}
/////
//bool canBeKey(T)() if (
//        isPointer!T
//    ) {
//    return true;
//}
//bool canBeKey(T)() if (is(T==struct)) {
//    enum testHash = canUseToHash!T;
//    enum testEquals = canUseOpEquals!T;
//
//    pragma(msg, "%s: safeHash: %s, safeOpEquals: %s".format(T.stringof, testHash, testEquals));
//    static if ( testHash && testEquals ) {
//        return true;
//    } else
//    // at this point T has no good hash and equals.
//    static if (__traits(isSame, TemplateOf!(T), std.typecons.Tuple)) {
//        return true;
//    } else {
//        // check field after field what we can do
//        static foreach (f; Fields!T) {
//            if ( !canBeKey!f ) {
//                return false;
//            }
//        }
//        return true;
//    }
//}
//bool canBeKey(T)() if (is(T==class)) {
//    enum testHash = canUseToHash!T;
//    enum testEquals = canUseOpEquals!T;
//
//    pragma(msg, "%s: safeHash: %s, safeOpEquals: %s".format(T.stringof, testHash, testEquals));
//    return testHash && testEquals;
//}
//private @trusted D trustedCast(S, D)(S r) { return cast(D) r; }
/////
//hash_t customHash(T)(const auto ref T v) @safe @nogc if ( !canUseToHash!(T) ) {
//    static if ( isIntegral!(T) ) {
//        return cast(hash_t)v;
//    }
//    else static if ( isPointer!T ) {
//        return cast(hash_t)v;
//    }
//    else static if ( isDelegate!T ) {
//        auto p = v.ptr;
//        auto f = (() @trusted {return v.funcptr;})();
//        return customHash(p) + customHash(f);
//    }
//    else static if ( is(T == string) ) {
//        // FNV-1a 64bit hash
//        hash_t h = 0xcbf29ce484222325;
//        foreach (const ubyte c; trustedCast!(string, ubyte[])(v))
//        {
//            h ^= c;
//            h *= 0x100000001b3;
//        }
//        return h;
//    }
//    else static if ( is(T == struct)) {
//        hash_t h = 0;
//        static if (__traits(isSame, TemplateOf!(T), std.typecons.Tuple)) {
//            foreach(m; v.expand) {
//                //pragma(msg, m);
//                h += customHash(m);
//            }
//        } else {
//            static foreach(m; __traits(allMembers, T)) {
//                //pragma(msg, m);
//                h += customHash(__traits(getMember, v, m));
//            }
//        }
//        return h;
//    }
//    else static if ( is(T == class) ) {
//        return true;
//    }
//    assert(0, "can't compute @safe and @nogc hash for " ~ T.stringof);
//}
/////
//hash_t customHash(T)(const T v) @safe @nogc if ( canUseToHash!T ) {
//    return v.toHash();
//}
//
//unittest
//{
//
//    static int int_a = 1;
//    static int function(int) f0 = (int x){
//        return 0;
//    };
//
//    class C0 {
//    }
//
//    class C1 {
//        override hash_t toHash() const {
//            auto v = new Object();
//            return 1;
//        }
//    }
//
//    class C2 {
//        override hash_t toHash() const @nogc @safe {
//            return 1;
//        }
//    }
//
//    class C3 {
//        int c;
//        override hash_t toHash() const @nogc @safe {
//            return 1;
//        }
//        override bool opEquals(Object o) const @safe @nogc {
//            C3 c3 = cast(C3)o;
//            return c3 && this.c == c3.c;
//        }
//    }
//
//    class C4 : C3 {
//    }
//
//    struct S0 {
//        int x;
//    }
//    struct S1 {
//        string s;
//    }
//    struct S2 {
//        string s;
//        float  f;
//        hash_t toHash() const @safe @nogc nothrow {
//            return 1;
//        }
//    }
//
//    struct S3 {
//        void function() f;
//    }
//
//    import std.meta;
//    import std.typecons;
//    C3 a = new C3;
//    C4 b = new C4;
//    static foreach(T; AliasSeq!(
//                    int,
//                    int*,
//                    string,
//                    void function(),
//                    Tuple!(int, int),
//                    Tuple!(int, string),
//                    S0,
//                    S1,
//                    S2,
//                    S3,
//                    C0,
//                    C1,
//                    C2,
//                    C3
//                )) {
//        static if ( canBeKey!T ) {
//            writefln("canBeKey!%s == true", T.stringof);
//        } else {
//            writefln("canBeKey!%s == false", T.stringof);
//            describe!T;
//        }
//        // writefln("%s: canUseToHash: %s, canUseOpEquals: %s", T.stringof, canUseToHash!T, canUseOpEquals!T);
//    }
//    int i = 1;
//    int delegate(int) dg = (int x) {
//        return i+x;
//    };
//    () @nogc @safe {
//        assert(customHash!ulong(5) == 5);
//        {
//            string abc0 = "abc";
//            string abc1 = "abc";
//            assert(customHash(abc0) == 0xe71fa2190541574b);
//            assert(abc0 == abc1 && customHash(abc0) == customHash(abc1));
//        }
//        {
//            // srtuct with plain int
//            S0 s0 = S0(0x55aa);
//            S0 s1 = S0(0x55aa);
//            assert(customHash(s0) == 0x55aa);
//            assert(s0 == s1 && customHash(s0) == customHash(s1));
//        }
//        {
//            // srtuct with plain string
//            S1 s0 = S1("abc");
//            S1 s1 = S1("abc");
//            assert(customHash(s0) == 0xe71fa2190541574b);
//            assert(s0 == s1 && customHash(s0)==customHash(s1));
//        }
//        {
//            // struct with toHash();
//            S2 s0 = S2("1", 1.0);
//            S2 s1 = S2("1", 1.0);
//            assert(s0 == s1 && customHash(s0) == customHash(s1));
//            assert(customHash(s0) == 1);
//        }
//        // test tuples
//        {
//            auto t0 = Tuple!(int, int)(1,1);
//            auto t1 = Tuple!(int, int)(1,1);
//            assert(customHash(t0) == 2);
//            assert(t0 == t1 && customHash(t0) == customHash(t1));
//            assert(customHash(Tuple!(string, int)("abc",1)) == 0xe71fa2190541574c);
//        }
//        {
//            // test pointers
//            int*    p0 = &int_a;
//            int*    p1 = p0;
//            assert(p0 == p1 && customHash(p0) == customHash(p1));
//        }
//        {
//            // test function
//            auto p0 = &f0;
//            auto p1 = p0;
//            assert(p0 == p1 && customHash(p0) == customHash(p1));
//        }
//        {
//            // test delegate
//            auto p0 = dg;
//            auto p1 = p0;
//            assert(p0 == p1 && customHash(p0) == customHash(p1));
//        }
//    }();
//}