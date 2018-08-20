import std.stdio;
import cachetools;
import cachetools.fifo;
import std.datetime.stopwatch;

CachePolicy!(int, int) p;

static this() {
    p = new FIFOPolicy!(int, int);
}

void f() @nogc @safe {
    auto c = makeCache!(int, int);
    c.policy = p;
    foreach(i;0..10000) {
        c.put(i,i);
    }
}

void main()
{
    auto r = benchmark!(f)(10000);
    writeln(r);
}

/// $dub run --compiler=ldc2 --build release
/// Performing "release" build using ldc2 for x86_64.
/// stdx-allocator 2.77.2: target for configuration "library" is up to date.
/// emsi_containers 0.7.0: target for configuration "library" is up to date.
/// cachetools ~master: building configuration "application"...
/// To force a rebuild of up-to-date targets, run again with --force.
/// Running ./cachetools 
/// [3 minutes, 487 ms, 147 μs, and 3 hnsecs]

/// after "resize"
///> dub run --compiler=ldc2 --build release
///Performing "release" build using ldc2 for x86_64.
///stdx-allocator 2.77.2: target for configuration "library" is up to date.
///cachetools ~master: building configuration "application"...
///To force a rebuild of up-to-date targets, run again with --force.
///Running ./cachetools 
///[49 secs, 999 ms, and 581 μs]

/// after refactoring
/// Igors-MacBook-Pro:cachetools igor$ ./cachetools
///[37 secs, 913 ms, 325 μs, and 8 hnsecs]