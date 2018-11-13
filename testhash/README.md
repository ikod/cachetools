## This is performance tester for hash table ##

During set up phase two arrays of 1_000_000 random integers
('write array' and 'read array') were created. This arrays used in subsequent tests.

Results description:

Table type - four options:
* internal associative array
* OAHashMap - this package implementation (using Mallocator),
* OAHashMap+GC - this package implementation(using GCAllocator),
* HashMap - emsi_containers hash map.

Time - time required for test. Less is better.

Memory - diff between GC.stat.used after and before test.

to run tests use: `dub run -b release --compiler ldc2`

setup: ldc2 1.11.0, OSX, MacBook Pro 2015

### Test #1: ###

1. place 'write' array into hash table
1. lookup integers from 'read array' in the table.

| table type               | time                          | memory            |
|--------------------------|-------------------------------|-------------------|
|int[int]                  | [292 ms, 490 μs, and 5 hnsecs]|  GC memory Δ 41MB |
|OAHashMap!(int,int)       | [189 ms, 35 μs, and 9 hnsecs] |  GC memory Δ 0MB  |
|OAHashMap!(int, int)+GC   | [198 ms, 44 μs, and 3 hnsecs] |  GC memory Δ 16MB |
|HashMap!(int, int)        | [762 ms, 270 μs, and 4 hnsecs]|  GC memory Δ 0MB  |


### Test #2 ###

Test performance on entry removal.

1. place 'write' array into hash table.
1. remove keys (list of keys for deletion formed from the 'read array') from the table.
1. lookup integers from 'write array' in the table.


| table type               | time                          | memory            |
|--------------------------|-------------------------------|-------------------|
|int[int] rem              | [373 ms, 710 μs, and 4 hnsecs]|  GC memory Δ 17MB |
|OAHashMap!(int,int) rem   | [244 ms, 833 μs, and 1 hnsec] |  GC memory Δ 0MB  |
|OAHashMap!(int,int)+GC rem| [302 ms and 215 μs]           |  GC memory Δ 16MB |
|HashMap!(int,int) rem     | [781 ms, 627 μs, and 9 hnsecs]|  GC memory Δ 0MB  |

### Test #3 ###

Use structure with some mix of fields instead of `int` as `value` type.
This is test for both performance and memory management.

1. for each key from 'write array' create instance of the struct, place it in table.
1. lookup integers from 'read array' in the table.

| table type               | time                          | memory            |
|--------------------------|-------------------------------|-------------------|
|LARGE[int]                | [512 ms, 681 μs, and 1 hnsec] |  GC memory Δ 109MB|
|OAHashMap!(int, LARGE)    | [465 ms, 336 μs, and 1 hnsec] |  GC memory Δ 0MB  |
|OAHashMap!(int, LARGE)+GC | [434 ms, 173 μs, and 7 hnsecs]|  GC memory Δ 88MB |
|HashMap!(int, LARGE)      | [1 sec, 461 ms, 928 μs, and 5]|  GC memory Δ 0MB  |

### Test #4 ###

Count words in Shakespeare texts (5M file).

| table type               | time                          | memory            |
|--------------------------|-------------------------------|-------------------|
|Shakespeare int[string]   | [138 ms, 830 μs, and 3 hnsecs]|  GC memory Δ 5MB  |
|Shakespeare OAHashMap     | [107 ms, 907 μs, and 7 hnsecs]|  GC memory Δ 1MB  |
|Shakespeare OAHashMap+GC  | [114 ms, 503 μs, and 8 hnsecs]|  GC memory Δ 5MB  |
|Shakespeare HashMap       | [296 ms, 557 μs, and 1 hnsec] |  GC memory Δ 1MB  |
