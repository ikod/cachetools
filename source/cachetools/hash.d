module cachetools.hash;

import std.traits;
import std.stdio;
import std.format;
import std.typecons;

ulong hash_function(T)(in T v) /* @nogc @safe inferred from class toHash */ if (is(T == class)) 
{
    return v.toHash();
}

hash_t hash_function(T)(in T v) @nogc @trusted if ( !is(T == class) )
{
    //
    // XXX this must be changed to core.internal.hash.hashOf when it become @nogc
    // https://github.com/dlang/druntime/blob/master/src/core/internal/hash.d
    //
    static if ( isNumeric!T ) {
        enum m = 0x5bd1e995;
        hash_t h = v;
        h ^= h >> 13;
        h *= m;
        h ^= h >> 15;
        return h;
    }
    else static if ( is(T == string) ) {
        // FNV-1a hash
        ulong h = 0xcbf29ce484222325;
        foreach (const ubyte c; cast(ubyte[]) v)
        {
            h ^= c;
            h *= 0x100000001b3;
        }
        return cast(hash_t)h;
    }
    else static if (is(T == class))
    {
        return v.toHash();
    }
    else
    {
        const(ubyte)[] bytes = (() @trusted => (cast(const(ubyte)*)&v)[0 .. T.sizeof])();
        ulong h = 0xcbf29ce484222325;
        foreach (const ubyte c; bytes)
        {
            h ^= c;
            h *= 0x100000001b3;
        }
        return cast(hash_t)h;
    }
}

@safe unittest
{
    assert(hash_function("abc") == cast(hash_t)0xe71fa2190541574b);
}
