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

| hash table               | time                          | memory            |
|--------------------------|-------------------------------|-------------------|
|std     | 293 ms and 632 μs               | GC memory Δ 41MB|
|c.t.    | 190 ms, 70 μs, and 3 hnsecs     | GC memory Δ 0MB|
|c.t.+GC | 187 ms, 401 μs, and 5 hnsecs    | GC memory Δ 16MB|
|emsi    | 651 ms, 328 μs, and 7 hnsecs    | GC memory Δ 0MB|

### Test #2 ###

Test performance on entry removal.

1. place 'write' array into hash table.
1. remove keys (list of keys for deletion formed from the 'read array') from the table.
1. lookup integers from 'write array' in the table.


| hash table        | time                          | memory            |
|--------------------------|-------------------------------|-------------------|
|std     | 340 ms, 264 μs, and 2 hnsecs    | GC memory Δ 17MB|
|c.t.    | 232 ms, 126 μs, and 2 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 246 ms, 727 μs, and 2 hnsecs    | GC memory Δ 16MB|
|emsi    | 688 ms, 116 μs, and 6 hnsecs    | GC memory Δ 0MB|

### Test #3 ###

Use structure with some mix of fields instead of `int` as `value` type.
This is test for both performance and memory management.

1. for each key from 'write array' create instance of the struct, place it in table.
1. lookup integers from 'read array' in the table.

| table type               | time                          | memory            |
|--------------------------|-------------------------------|-------------------|
|std     | 483 ms and 226 μs               | GC memory Δ 109MB|
|c.t.    | 414 ms, 165 μs, and 9 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 406 ms, 201 μs, and 1 hnsec     | GC memory Δ 88MB|
|emsi    | 1 sec, 394 ms, 390 μs, and 3 h  | GC memory Δ 0MB|

### Test #4 ###

Count words in Shakespeare texts (5M file).

| table type               | time                          | memory            |
|--------------------------|-------------------------------|-------------------|
|std     | 141 ms and 366 μs               | GC memory Δ 5MB|
|c.t.    | 122 ms, 849 μs, and 3 hnsecs    | GC memory Δ 1MB|
|c.t.+GC | 121 ms, 552 μs, and 8 hnsecs    | GC memory Δ 5MB|
|emsi    | 305 ms, 993 μs, and 6 hnsecs    | GC memory Δ 1MB|

```
        Test inserts and lookups int[int]         
        =================================         
|std     | 291 ms, 579 μs, and 8 hnsecs    | GC memory Δ 41MB|
|c.t.    | 180 ms, 852 μs, and 4 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 178 ms and 106 μs               | GC memory Δ 16MB|
|emsi    | 642 ms, 560 μs, and 7 hnsecs    | GC memory Δ 0MB|

     Test insert, remove, lookup for int[int]     
     =======================================      
|std     | 326 ms, 234 μs, and 1 hnsec     | GC memory Δ 17MB|
|c.t.    | 230 ms, 121 μs, and 9 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 235 ms and 426 μs               | GC memory Δ 16MB|
|emsi    | 676 ms, 971 μs, and 8 hnsecs    | GC memory Δ 0MB|

     Test inserts and lookups for struct[int]     
     =======================================      
|std     | 464 ms, 347 μs, and 4 hnsecs    | GC memory Δ 109MB|
|c.t.    | 396 ms, 443 μs, and 2 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 397 ms, 112 μs, and 9 hnsecs    | GC memory Δ 88MB|
|emsi    | 1 sec, 343 ms, 178 μs, and 7 h  | GC memory Δ 0MB|

     Test inserts and lookups for int[struct]     
     =======================================      
|std     | 376 ms, 172 μs, and 2 hnsecs    | GC memory Δ 109MB|
|c.t.    | 368 ms, 806 μs, and 9 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 398 ms, 859 μs, and 4 hnsecs    | GC memory Δ 88MB|
|emsi    | 1 sec, 592 ms, 714 μs, and 3 h  | GC memory Δ 0MB|

     Test inserts and lookups for int[class]      
     =======================================      
|std     | 1 sec, 467 ms, and 167 μs       | GC memory Δ 171MB|
|c.t.    | 975 ms, 893 μs, and 3 hnsecs    | GC memory Δ 164MB|
|c.t.+GC | 397 ms, 876 μs, and 3 hnsecs    | GC memory Δ 88MB|

          Test word counting int[string]          
          =============================           
|std     | 120 ms, 151 μs, and 3 hnsecs    | GC memory Δ 5MB|
|c.t.    | 109 ms, 424 μs, and 1 hnsec     | GC memory Δ 1MB|
|c.t.+GC | 106 ms, 643 μs, and 5 hnsecs    | GC memory Δ 5MB|
|emsi    | 295 ms, 801 μs, and 6 hnsecs    | GC memory Δ 1MB|

        Test double-linked list DList!int         
        =================================         
|std     | 56 ms, 249 μs, and 7 hnsecs     | GC memory Δ 30MB|
|c.t.    | 83 ms, 7 μs, and 5 hnsecs       | GC memory Δ 0MB|
|c.t.+GC | 42 ms, 881 μs, and 4 hnsecs     | GC memory Δ 30MB|
|emsi    | 81 ms, 668 μs, and 9 hnsecs     | GC memory Δ 0MB|

        Test double-linked list of structs        
        ==================================        
|std     | 102 ms and 490 μs               | GC memory Δ 122MB|
|c.t.    | 99 ms, 123 μs, and 8 hnsecs     | GC memory Δ 0MB|
|c.t.+GC | 87 ms, 762 μs, and 1 hnsec      | GC memory Δ 122MB|
|emsi    | 424 ms, 141 μs, and 4 hnsecs    | GC memory Δ 0MB|

                    Test cache                    
                    ==========                    
|c.t     | 1 sec, 456 ms, 835 μs, and 7 h  | GC memory Δ 0MB|
|c.t+GC  | 1 sec, 404 ms, and 243 μs       | GC memory Δ 141MB|

```