module cachetools.internal;

private import std.typecons;
private import std.traits;

template StoredType(T)
{
    static if ( is (T==immutable) || is(T==const) )
    {
        static if ( is(T==class) )
        {
            alias StoredType = Rebindable!T;
        }
        else
        {
            alias StoredType = Unqual!T;
        }
    }
    else
    {
        alias StoredType = T;
    }
}
