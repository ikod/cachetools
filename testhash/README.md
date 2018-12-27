## This is performance tester for hash table ##

During set up phase two arrays of 1_000_000 random integers
('write array' and 'read array') were created. This arrays used in subsequent tests.

Results description:

Hash table - four options:
* std - dlang AA
* c.t - this package (cachetools) implementation (using Mallocator),
* c.t+GC - this package (cachetools) implementation(using GCAllocator),
* emsi - emsi_containers hash map.

Lists:
* unr - unrolled lists

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

### Test caches ###

Test 1024 entries caches (LRU and 2Q) for words stream from Shakespeare tests.


```

        Test inserts and lookups int[int]         
        =================================         
|std         | 315 ms, 459 μs, and 7 hnsecs    | GC memory Δ  41.65 MB|
|c.t.        | 177 ms, 280 μs, and 7 hnsecs    | GC memory Δ   0.00 MB|
|c.t.+GC     | 198 ms, 736 μs, and 6 hnsecs    | GC memory Δ  16.00 MB|
|emsi        | 588 ms and 974 μs               | GC memory Δ   0.00 MB|

                    Test scan                     
                    =========                     
|std         | 2 secs, 477 ms, 982 μs, and 4   | GC memory Δ  19.20 MB|
|c.t.        | 2 secs, 208 ms, 28 μs, and 3 h  | GC memory Δ   0.00 MB|

     Test insert, remove, lookup for int[int]     
     =======================================      
|std         | 344 ms, 420 μs, and 1 hnsec     | GC memory Δ  17.65 MB|
|c.t.        | 229 ms, 314 μs, and 5 hnsecs    | GC memory Δ   0.00 MB|
|c.t.+GC     | 216 ms, 591 μs, and 6 hnsecs    | GC memory Δ  16.00 MB|
|emsi        | 654 ms, 657 μs, and 1 hnsec     | GC memory Δ   0.00 MB|

     Test inserts and lookups for struct[int]     
     =======================================      
|std         | 325 ms, 604 μs, and 7 hnsecs    | GC memory Δ  70.59 MB|
|c.t.        | 347 ms, 79 μs, and 8 hnsecs     | GC memory Δ   0.00 MB|
|c.t.+GC     | 332 ms, 176 μs, and 8 hnsecs    | GC memory Δ  72.00 MB|
|emsi        | 767 ms, 620 μs, and 4 hnsecs    | GC memory Δ   0.00 MB|

     Test inserts and lookups for int[struct]     
     =======================================      
|std         | 337 ms, 936 μs, and 4 hnsecs    | GC memory Δ  70.59 MB|
|c.t.        | 340 ms, 263 μs, and 9 hnsecs    | GC memory Δ   0.00 MB|
|c.t.+GC     | 364 ms, 182 μs, and 7 hnsecs    | GC memory Δ  72.00 MB|
|emsi        | 882 ms and 172 μs               | GC memory Δ   0.00 MB|

     Test inserts and lookups for int[class]      
     =======================================      
|std         | 1 sec, 265 ms, 540 μs, and 1 h  | GC memory Δ 267.50 MB|
|c.t.        | 588 ms and 168 μs               | GC memory Δ 244.14 MB|
|c.t.+GC     | 352 ms, 569 μs, and 7 hnsecs    | GC memory Δ  72.00 MB|

          Test word counting int[string]          
          =============================           
|std         | 75 ms, 850 μs, and 2 hnsecs     | GC memory Δ   4.06 MB|
|c.t.        | 77 ms, 897 μs, and 7 hnsecs     | GC memory Δ   0.00 MB|
|c.t.+GC     | 67 ms, 807 μs, and 5 hnsecs     | GC memory Δ   4.00 MB|
|correctness | 137 ms and 694 μs               | GC memory Δ   4.00 MB|

        Test double-linked list DList!int         
        =================================         
|std         | 71 ms, 197 μs, and 4 hnsecs     | GC memory Δ  30.52 MB|
|c.t.        | 143 ms, 571 μs, and 9 hnsecs    | GC memory Δ   0.00 MB|
|c.t.+GC     | 77 ms, 396 μs, and 3 hnsecs     | GC memory Δ  27.47 MB|
|c.t.unroll  | 21 ms, 476 μs, and 7 hnsecs     | GC memory Δ   0.00 MB|
|c.t.unr+GC  | 28 ms, 119 μs, and 2 hnsecs     | GC memory Δ  13.73 MB|
|emsiunroll  | 28 ms, 897 μs, and 4 hnsecs     | GC memory Δ   0.00 MB|

        Test single-linked list SList!int         
        =================================         
|std         | 62 ms, 791 μs, and 8 hnsecs     | GC memory Δ  15.26 MB|
|c.t.        | 122 ms, 532 μs, and 2 hnsecs    | GC memory Δ   0.00 MB|
|c.t.+GC     | 69 ms, 339 μs, and 7 hnsecs     | GC memory Δ  13.73 MB|
|emsi        | 112 ms, 329 μs, and 7 hnsecs    | GC memory Δ   0.00 MB|

        Test double-linked list of structs        
        ==================================        
|std         | 224 ms, 788 μs, and 5 hnsecs    | GC memory Δ 111.35 MB|
|c.t.        | 174 ms, 305 μs, and 3 hnsecs    | GC memory Δ   0.00 MB|
|c.t.+GC     | 139 ms, 432 μs, and 6 hnsecs    | GC memory Δ 109.86 MB|
|c.t.unr     | 81 ms and 267 μs                | GC memory Δ   0.00 MB|
|c.t.unr+GC  | 99 ms and 283 μs                | GC memory Δ 109.86 MB|
|emsi        | 196 ms, 768 μs, and 2 hnsecs    | GC memory Δ   0.00 MB|

   Test double-linked list of structs with ref    
   ===========================================    
|std         | 194 ms and 33 μs                | GC memory Δ 111.73 MB|
|c.t.        | 570 ms and 743 μs               | GC memory Δ   0.00 MB|
|c.t.+GC     | 130 ms, 139 μs, and 9 hnsecs    | GC memory Δ 109.86 MB|
|c.t.unr     | 165 ms, 779 μs, and 6 hnsecs    | GC memory Δ   0.00 MB|
|c.t.unr+GC  | 75 ms, 378 μs, and 4 hnsecs     | GC memory Δ  73.24 MB|
|emsi        | 467 ms, 417 μs, and 9 hnsecs    | GC memory Δ   0.00 MB|

                    Test cache                    
                    ==========                    
|lru         | 804 ms, 557 μs, and 3 hnsecs    | GC memory Δ   0.00 MB| hits 0.63|
|lru+GC      | 360 ms, 391 μs, and 7 hnsecs    | GC memory Δ   0.16 MB| hits 0.63|
|2Q          | 308 ms, 548 μs, and 5 hnsecs    | GC memory Δ   0.00 MB| hits 0.68|
|2Q+GC       | 294 ms, 379 μs, and 4 hnsecs    | GC memory Δ   0.17 MB| hits 0.68|

```