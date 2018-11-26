## This is performance tester for hash table ##

During set up phase two arrays of 1_000_000 random integers
('write array' and 'read array') were created. This arrays used in subsequent tests.

Results description:

Hash table - four options:
* std - dlang AA
* c.t - this package (cachetools) implementation (using Mallocator),
* c.t+GC - this package (cachetools) implementation(using GCAllocator),
* emsi - emsi_containers hash map.

Time - time required for test. Less is better.

Memory - diff between GC.stat.used after and before test.

to run tests use: `dub run -b release --compiler ldc2`

setup: ldc2 1.11.0, OSX, MacBook Pro 2015

### Test #1: ###

1. place 'write' array into hash table
1. lookup integers from 'read array' in the table.

### Test #2 ###

Test performance on entry removal.

1. place 'write' array into hash table.
1. remove keys (list of keys for deletion formed from the 'read array') from the table.
1. lookup integers from 'write array' in the table.


### Test #3 ###

Use structure with some mix of fields instead of `int` as `value` type.
This is test for both performance and memory management.

1. for each key from 'write array' create instance of the struct, place it in table.
1. lookup integers from 'read array' in the table.

### Test #4 ###

Use structure with some mix of fields instead of `int` as `key` type.
This is test for both performance and memory management.

1. for each key from 'write array' create instance of the struct, place it in table.
1. lookup structs built from 'read array' in the table.

### Test #5 ###

Use class with some mix of fields instead of `int` as `key` type.
This is test for both performance and memory management.

1. for each key from 'write array' create instance of the class, place it in table.
1. lookup class built from 'read array' in the table.

### Test #6 ###

Count words in Shakespeare texts (5M file).


### Tests 7-9 ###

Test performance for internal list implementations

```
        Test inserts and lookups int[int]         
        =================================         
|std     | 303 ms, 541 μs, and 3 hnsecs    | GC memory Δ 41MB|
|c.t.    | 181 ms, 173 μs, and 2 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 184 ms, 594 μs, and 5 hnsecs    | GC memory Δ 16MB|
|emsi    | 642 ms and 120 μs               | GC memory Δ 0MB|

     Test insert, remove, lookup for int[int]     
     =======================================      
|std     | 327 ms, 982 μs, and 1 hnsec     | GC memory Δ 17MB|
|c.t.    | 229 ms, 11 μs, and 7 hnsecs     | GC memory Δ 0MB|
|c.t.+GC | 240 ms, 135 μs, and 4 hnsecs    | GC memory Δ 16MB|
|emsi    | 678 ms, 931 μs, and 9 hnsecs    | GC memory Δ 0MB|

     Test inserts and lookups for struct[int]     
     =======================================      
|std     | 468 ms, 411 μs, and 7 hnsecs    | GC memory Δ 109MB|
|c.t.    | 392 ms, 146 μs, and 1 hnsec     | GC memory Δ 0MB|
|c.t.+GC | 384 ms, 771 μs, and 5 hnsecs    | GC memory Δ 88MB|
|emsi    | 1 sec, 328 ms, 974 μs, and 9 h  | GC memory Δ 0MB|

     Test inserts and lookups for int[struct]     
     =======================================      
|std     | 380 ms, 408 μs, and 8 hnsecs    | GC memory Δ 109MB|
|c.t.    | 372 ms, 920 μs, and 6 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 389 ms, 142 μs, and 6 hnsecs    | GC memory Δ 88MB|
|emsi    | 1 sec, 484 ms, 927 μs, and 6 h  | GC memory Δ 0MB|

     Test inserts and lookups for int[class]      
     =======================================      
|std     | 1 sec, 231 ms, 665 μs, and 7 h  | GC memory Δ 291MB|
|c.t.    | 1 sec, 281 ms, 496 μs, and 6 h  | GC memory Δ 103MB|
|c.t.+GC | 387 ms, 246 μs, and 5 hnsecs    | GC memory Δ 88MB|

          Test word counting int[string]          
          =============================           
|std     | 125 ms, 358 μs, and 9 hnsecs    | GC memory Δ 5MB|
|c.t.    | 109 ms, 185 μs, and 7 hnsecs    | GC memory Δ 1MB|
|c.t.+GC | 145 ms, 116 μs, and 2 hnsecs    | GC memory Δ 5MB|
|emsi    | 273 ms, 343 μs, and 2 hnsecs    | GC memory Δ 1MB|

        Test double-linked list DList!int         
        =================================         
|std     | 91 ms, 436 μs, and 1 hnsec      | GC memory Δ 30MB|
|c.t.    | 85 ms, 641 μs, and 7 hnsecs     | GC memory Δ 0MB|
|c.t.+GC | 72 ms, 688 μs, and 7 hnsecs     | GC memory Δ 30MB|
|emsi    | 85 ms, 28 μs, and 6 hnsecs      | GC memory Δ 0MB|

        Test double-linked list of structs        
        ==================================        
|std     | 197 ms, 628 μs, and 6 hnsecs    | GC memory Δ 122MB|
|c.t.    | 136 ms, 848 μs, and 5 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 179 ms, 359 μs, and 2 hnsecs    | GC memory Δ 122MB|
|emsi    | 406 ms, 512 μs, and 7 hnsecs    | GC memory Δ 0MB|

                    Test cache                    
                    ==========                    
|c.t     | 1 sec, 487 ms, 245 μs, and 8 h  | GC memory Δ 0MB|
|c.t+GC  | 1 sec, 657 ms, 419 μs, and 6 h  | GC memory Δ 141MB|


```