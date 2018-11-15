import std.stdio;
import std.random;
import std.datetime.stopwatch;
import std.algorithm, std.range;
import std.conv;
import std.experimental.allocator.gc_allocator;
import core.memory;

// emsi_containers
import containers.hashmap;
import cachetools.containers.hashmap: CTHashMap = HashMap;

immutable iterations = 1_000_000;
immutable trials = 1;
int hits;

int[iterations] randw, randr;
static this()
{
    auto rnd = Random(unpredictableSeed);
    foreach(i;0..iterations)
    {
        randw[i] = uniform(0, iterations, rnd);
        randr[i] = uniform(0, iterations, rnd);
    }
}

GC.Stats gcstart, gcstop;

void f_AA() @safe {
    gcstart = () @trusted {return GC.stats;}();

    int[int] c;
    foreach(i;0..iterations) {
        int k = randw[i];
        c[k] = i;
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
    gcstop = () @trusted {return GC.stats;} ();
}

void f_oahashmap() @safe {
    gcstart = () @trusted {return GC.stats;}();

    CTHashMap!(int, int) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c.put(k, i);
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
    gcstop = () @trusted {return GC.stats;} ();
}
void f_oahashmapGC() @safe {
    gcstart = () @trusted {return GC.stats;}();

    CTHashMap!(int, int, GCAllocator) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c.put(k, i);
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
    gcstop = () @trusted {return GC.stats;} ();
}


void f_hashmap() {
    gcstart = () @trusted {return GC.stats;}();

    HashMap!(int, int) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c[k] = i;
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
    gcstop = () @trusted {return GC.stats;} ();
}

void f_AA_remove() @safe {
    gcstart = () @trusted {return GC.stats;}();

    int[int] c;
    foreach(i;0..iterations) {
        int k = randw[i];
        c[k] = i;
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        c.remove(k);
    }
    foreach(i; 0..iterations) {
        int k = randw[i];
        auto v = k in c;
    }
    gcstop = () @trusted {return GC.stats;} ();
}
void f_oahashmapGC_remove() @safe {
    gcstart = () @trusted {return GC.stats;}();

    CTHashMap!(int, int, GCAllocator) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c.put(k, i);
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        c.remove(k);
    }
    foreach(i; 0..iterations) {
        int k = randw[i];
        auto v = k in c;
    }
    gcstop = () @trusted {return GC.stats;} ();
}
void f_oahashmap_remove() @safe {
    gcstart = () @trusted {return GC.stats;}();

    CTHashMap!(int, int) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c.put(k, i);
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        c.remove(k);
    }
    foreach(i; 0..iterations) {
        int k = randw[i];
        auto v = k in c;
    }
    gcstop = () @trusted {return GC.stats;} ();
}
void f_hashmap_remove() {
    gcstart = () @trusted {return GC.stats;}();

    HashMap!(int, int) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c[k] = i;
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        c.remove(k);
    }
    foreach(i; 0..iterations) {
        int k = randw[i];
        auto v = k in c;
    }
    gcstop = () @trusted {return GC.stats;} ();
}

void shakespeare_std()
{
    gcstart = () @trusted {return GC.stats;} ();

    int[string] count;
    void updateCount(char[] word) {
        auto ptr = cast(string)word in count;
        if (!ptr)
            count[word.idup] = 1;
        else
            (*ptr)++;
    }

    auto f = File("t8.shakespeare.txt", "r");
    foreach(word; f.byLine.map!splitter.joiner) {
          updateCount(word);
    }
    gcstop = () @trusted {return GC.stats;} ();
}
void shakespeare_OAHashMap()
{
    gcstart = () @trusted {return GC.stats;} ();

    CTHashMap!(string, int) count;
    void updateCount(char[] word) {
        auto ptr = cast(string)word in count;
        if (!ptr)
            count.put(word.idup, 1);
        else
            (*ptr)++;
    }

    auto f = File("t8.shakespeare.txt", "r");
    foreach(word; f.byLine.map!splitter.joiner) {
          updateCount(word);
    }
    gcstop = () @trusted {return GC.stats;} ();
}
void shakespeare_OAHashMapGC()
{
    gcstart = () @trusted {return GC.stats;} ();

    CTHashMap!(string, int, GCAllocator) count;
    void updateCount(char[] word) {
        auto ptr = cast(string)word in count;
        if (!ptr)
            count.put(word.idup, 1);
        else
            (*ptr)++;
    }

    auto f = File("t8.shakespeare.txt", "r");
    foreach(word; f.byLine.map!splitter.joiner) {
          updateCount(word);
    }
    gcstop = () @trusted {return GC.stats;} ();
}
void shakespeare_HashMap()
{
    gcstart = () @trusted {return GC.stats;} ();

    HashMap!(string, int) count;
    void updateCount(char[] word) {
        auto ptr = cast(string)word in count;
        if (!ptr)
            count[word.idup] = 1;
        else
            (*ptr)++;
    }

    auto f = File("t8.shakespeare.txt", "r");
    foreach(word; f.byLine.map!splitter.joiner) {
          updateCount(word);
    }
    gcstop = () @trusted {return GC.stats;} ();
}

struct LARGE {
    import std.conv;
    int i;
    long l;
    double d;
    string s;
    long l1;
    long l2;
    long l3;
    long l4;
    this(int i) @safe @nogc
    {
        i = i;
        l = i;
        d = i;
        s = "large struct";// to!string(i);
    }
}
void LARGE_AA() @safe {
    gcstart = () @trusted {return GC.stats;}();

    LARGE[int] c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c[k] = LARGE(i);
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
    gcstop = () @trusted {return GC.stats;}();
}
void OALARGE() @safe {
    gcstart = () @trusted {return GC.stats;}();

    CTHashMap!(int, LARGE) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c.put(k, LARGE(i));
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
    gcstop = () @trusted {return GC.stats;}();
}
void OALARGE_GC() @safe {
    gcstart = () @trusted {return GC.stats;}();

    CTHashMap!(int, LARGE, GCAllocator) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c.put(k, LARGE(i));
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
    gcstop = () @trusted {return GC.stats;}();
}
void HMLARGE() {
    gcstart = () @trusted {return GC.stats;}();

    HashMap!(int, LARGE) c;

    foreach(i;0..iterations) {
        int k = randw[i];
        c[k] = LARGE(i);
    }

    foreach(i; 0..iterations) {
        int k = randr[i];
        auto v = k in c;
        if ( v ) {
            hits++;
        }
    }
    gcstop = () @trusted {return GC.stats;}();
}

void test_dlist_std()
{
    import std.container.dlist;
    gcstart = () @trusted {return GC.stats;}();
    auto intList = new DList!int;
    foreach(i; randw)
    {
        intList.insertBack(i);
    }
    gcstop = () @trusted {return GC.stats;}();
}

void test_dlist_cachetools() @safe
{
    import cachetools.containers.lists;
    gcstart = () @trusted {return GC.stats;}();
    DList!int intList;
    foreach(i; randw)
    {
        intList.insert_last(i);
    }
    gcstop = () @trusted {return GC.stats;}();
}

void test_dlist_cachetools_GC() @safe
{
    import cachetools.containers.lists;
    gcstart = () @trusted {return GC.stats;}();
    DList!(int, GCAllocator) intList;
    foreach(i; randw)
    {
        intList.insert_last(i);
    }
    gcstop = () @trusted {return GC.stats;}();
}

void test_dlist_emsi()
{
    import containers.unrolledlist;
    gcstart = () @trusted {return GC.stats;}();
    UnrolledList!int intList;
    foreach(i; randw)
    {
        intList.insertBack(i);
    }
    gcstop = () @trusted {return GC.stats;}();
}
// --
void test_dlist_std_LARGE()
{
    import std.container.dlist;
    gcstart = () @trusted {return GC.stats;}();
    auto list = new DList!LARGE;
    foreach(i; randw)
    {
        list.insertBack(LARGE(i));
    }
    gcstop = () @trusted {return GC.stats;}();
}

void test_dlist_cachetools_LARGE() @safe
{
    import cachetools.containers.lists;
    gcstart = () @trusted {return GC.stats;}();
    DList!LARGE list;
    foreach(i; randw)
    {
        list.insert_last(LARGE(i));
    }
    gcstop = () @trusted {return GC.stats;}();
}

void test_dlist_cachetools_LARGE_GC() @safe
{
    import cachetools.containers.lists;
    gcstart = () @trusted {return GC.stats;}();
    DList!(LARGE, GCAllocator) list;
    foreach(i; randw)
    {
        list.insert_last(LARGE(i));
    }
    gcstop = () @trusted {return GC.stats;}();
}

void test_dlist_emsi_LARGE()
{
    import containers.unrolledlist;
    gcstart = () @trusted {return GC.stats;}();
    UnrolledList!LARGE list;
    foreach(i; randw)
    {
        list.insertBack(LARGE(i));
    }
    gcstop = () @trusted {return GC.stats;}();
}

void main()
{
    import std.string;
    string test;
    Duration[1] r;
    string fmt = "%-7.7s %-31.31s GC memory Δ %dMB";

    writeln("\n", center(" Test inserts and lookups int[int] ", 50, ' '));
    writeln(      center(" ================================= ", 50, ' '));

    GC.collect();GC.minimize();
    test = "std";
    r = benchmark!(f_AA)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.";
    r = benchmark!(f_oahashmap)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.+GC";
    r = benchmark!(f_oahashmapGC)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    version(Posix)
    {
        // emsi-containers do not work for me under windows
        GC.collect();GC.minimize();
        test = "emsi";
        r = benchmark!(f_hashmap)(trials);
        writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);
    }

    writeln("\n", center(" Test insert, remove, lookup for int[int]", 50, ' '));
    writeln(      center(" ======================================= ", 50, ' '));

    GC.collect();GC.minimize();
    test = "std";
    r = benchmark!(f_AA_remove)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.";
    r = benchmark!(f_oahashmap_remove)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.+GC";
    r = benchmark!(f_oahashmapGC_remove)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    version(Posix)
    {
        // emsi-containers do not work for me under windows
        GC.collect();GC.minimize();
        test = "emsi";
        r = benchmark!(f_hashmap_remove)(trials);
        writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);
    }

    writeln("\n", center(" Test inserts and lookups for struct[int] ", 50, ' '));
    writeln(      center(" ======================================= ", 50, ' '));

    GC.collect();GC.minimize();
    test = "std";
    r = benchmark!(LARGE_AA)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.";
    r = benchmark!(OALARGE)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.+GC";
    r = benchmark!(OALARGE_GC)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    version(Posix)
    {
        // emsi-containers do not work for me under windows
        GC.collect();GC.minimize();
        test = "emsi";
        r = benchmark!(HMLARGE)(trials);
        writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);
    }

    writeln("\n", center(" Test word counting int[string]", 50, ' '));
    writeln(      center(" ============================= ", 50, ' '));

    GC.collect();GC.minimize();
    test = "std";
    r = benchmark!shakespeare_std(1);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.";
    r = benchmark!shakespeare_OAHashMap(1);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.+GC";
    r = benchmark!shakespeare_OAHashMapGC(1);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    version(Posix)
    {
        // emsi-containers do not work for me under windows
        GC.collect();GC.minimize();
        test = "emsi  ";
        r = benchmark!shakespeare_HashMap(1);
        writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);
    }

    writeln("\n", center(" Test double-linked list DList!int ", 50, ' '));
    writeln(      center(" ================================= ", 50, ' '));

    GC.collect();GC.minimize();
    test = "std";
    r = benchmark!(test_dlist_std)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.";
    r = benchmark!(test_dlist_cachetools)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.+GC";
    r = benchmark!(test_dlist_cachetools_GC)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "emsi";
    r = benchmark!(test_dlist_cachetools)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    writeln("\n", center(" Test double-linked list of structs ", 50, ' '));
    writeln(      center(" ================================== ", 50, ' '));

    GC.collect();GC.minimize();
    test = "std";
    r = benchmark!(test_dlist_std_LARGE)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.";
    r = benchmark!(test_dlist_cachetools_LARGE)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "c.t.+GC";
    r = benchmark!(test_dlist_cachetools_LARGE_GC)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

    GC.collect();GC.minimize();
    test = "emsi";
    r = benchmark!(test_dlist_emsi_LARGE)(trials);
    writefln(fmt, test, to!string(r), (gcstop.usedSize - gcstart.usedSize)/1024/1024);

}
