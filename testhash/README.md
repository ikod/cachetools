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
|std     | 277 ms, 841 μs, and 8 hnsecs    | GC memory Δ 41MB|
|c.t.    | 182 ms, 354 μs, and 1 hnsec     | GC memory Δ 0MB|
|c.t.+GC | 182 ms, 867 μs, and 4 hnsecs    | GC memory Δ 16MB|
|emsi    | 610 ms, 193 μs, and 3 hnsecs    | GC memory Δ 0MB|

     Test insert, remove, lookup for int[int]     
     =======================================      
|std     | 327 ms, 489 μs, and 4 hnsecs    | GC memory Δ 17MB|
|c.t.    | 232 ms, 498 μs, and 3 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 233 ms, 632 μs, and 9 hnsecs    | GC memory Δ 16MB|
|emsi    | 644 ms, 370 μs, and 8 hnsecs    | GC memory Δ 0MB|

     Test inserts and lookups for struct[int]     
     =======================================      
|std     | 463 ms, 945 μs, and 1 hnsec     | GC memory Δ 109MB|
|c.t.    | 386 ms, 950 μs, and 8 hnsecs    | GC memory Δ 0MB|
|c.t.+GC | 383 ms, 709 μs, and 9 hnsecs    | GC memory Δ 88MB|
|emsi    | 1 sec, 282 ms, 897 μs, and 3 h  | GC memory Δ 0MB|

          Test word counting int[string]          
          =============================           
|std     | 128 ms, 385 μs, and 4 hnsecs    | GC memory Δ 5MB|
|c.t.    | 106 ms, 890 μs, and 5 hnsecs    | GC memory Δ 1MB|
|c.t.+GC | 114 ms, 499 μs, and 6 hnsecs    | GC memory Δ 5MB|
|emsi    | 282 ms, 294 μs, and 6 hnsecs    | GC memory Δ 1MB|

        Test double-linked list DList!int         
        =================================         
|std     | 56 ms, 658 μs, and 4 hnsecs     | GC memory Δ 30MB|
|c.t.    | 80 ms, 537 μs, and 5 hnsecs     | GC memory Δ 0MB|
|c.t.+GC | 42 ms, 8 μs, and 2 hnsecs       | GC memory Δ 30MB|
|emsi    | 79 ms, 307 μs, and 4 hnsecs     | GC memory Δ 0MB|

        Test double-linked list of structs        
        ==================================        
|std     | 307 ms, 468 μs, and 7 hnsecs    | GC memory Δ 122MB|
|c.t.    | 89 ms, 477 μs, and 6 hnsecs     | GC memory Δ 0MB|
|c.t.+GC | 216 ms, 175 μs, and 8 hnsecs    | GC memory Δ 122MB|
|emsi    | 401 ms, 938 μs, and 8 hnsecs    | GC memory Δ 0MB|

                    Test cache                    
                    ==========                    
|c.t     | 1 sec, 402 ms, 425 μs, and 9 h  | GC memory Δ 0MB|
|c.t+GC  | 1 sec, 489 ms, and 436 μs       | GC memory Δ 141MB|

```