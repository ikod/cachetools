import std.stdio;
import cachetools;
import cachetools.fifo;
import cachetools.containers.hashmap;
import std.datetime.stopwatch;
import std.random;
import std.experimental.logger;

CachePolicy!(int, int) p;
int hits;

immutable iterations = 1_000;

static this() {
    auto fifo = new FIFOPolicy!(int, int);
    fifo.maxLength(iterations/2);
    p = fifo;
}


void f() @safe {
    auto c = makeCache!(int, int);
    auto rnd = Random(unpredictableSeed);

    c.policy = p;
    foreach(i;0..iterations) {
        int k = uniform(0, iterations, rnd);
        //writeln(k);
        c.put(k,i);
    }

    foreach(_; 0..iterations) {
        int k = uniform(0, iterations, rnd);
        auto v = c.get(k);
        if ( !v.empty ) {
            hits++;
        }
    }
}

void f_AA() @safe {
    int[int] c;
    auto rnd = Random(unpredictableSeed);

    foreach(i;0..iterations) {
        int k = uniform(0, iterations, rnd);
        c[k] = i;
    }

    foreach(_; 0..iterations) {
        int k = uniform(0, iterations, rnd);
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
}

void f_hashmap() @safe {
    HashMap!(int, int) c;
    auto rnd = Random(unpredictableSeed);

    foreach(i;0..iterations) {
        int k = uniform(0, iterations, rnd);
        c.put(k, i);
    }

    foreach(_; 0..iterations) {
        int k = uniform(0, iterations, rnd);
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
}

immutable trials = 100;

void main()
{
    globalLogLevel = LogLevel.info;
    auto r = benchmark!(f)(trials);
    writeln(r);
    writefln("hit rate = %f%%", (1e2*hits)/(trials*iterations));

    hits = 0;
    r = benchmark!(f_AA)(trials);
    writeln(r);
    writefln("hit rate = %f%%", (1e2*hits)/(trials*iterations));

    hits = 0;
    r = benchmark!(f_hashmap)(trials);
    writeln(r);
    writefln("hit rate = %f%%", (1e2*hits)/(trials*iterations));
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

/// 26.08.2018 - FIFO policy: 'second chance' implemented, removed list_map
/// test of random put/get
/// [30 secs, 329 ms, 307 μs, and 8 hnsecs]
/// hit rate = 49.996496%
