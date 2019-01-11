# @safe @nogc containers #

This is @safe and @nogc hash map and lists collection primary for usage in cachetools (but can be used externally).

## HashMap ##

Open-addressing hash map.

It allocates (using std.experimental allocator) bucket array where it store inline hashes, keys and values, only at start or during table resize, so that we avoid any allocations during inserts.

All HashMap methods are @safe and inherit @nogc from your Key and Value properties. If

1. available key comparison function is `@nogc`
1. available hash computation for key is `@nogc`

then you can use HashMap methods in `@nogc` code.


To operate on **classes as key** it require:

* `@safe` (or `@trusted`) implementation for key comparison function `opEquals(const C other)`. *HashMap can't use built-in object opEquals*.
* `@safe` (or `@trusted`) `toHash` function.

For anything other than classes HashTable can use your own or builtin comparison or `toHash` functions.

Update methods:

* `put(k, v)` - put item in the hash table. It can replace old value if already presented in table.
* `HashMap[k] = v` - put item in the hash table. It can replace old value if already presented in table.
* `remove(k)` - remove key `k` from table. Returns `true` if key actually were removed, `false` otherwise.
* `clear()` - drop all keys from table.

Lookup methods:

* `k in HashMap` - returns pointer to value if key `k` presented in table or `null` otherwise.
* `get(k, default)` - returns stored value if key `k` presented in table, returns `default` otherwize. `default` can be callable with return type same as Value type. Callable default will be called only if required.
* `getOrAdd(k, default)` - returns pointer to stored value if key `k` in table, insert `default` otherwize and return pointer to this value. `default` can be callable with return type same as Value type. Callable default will be called only if required.
* `HashMap[k]` - opIndex - return reference to stored value if key `k` presented in table or throw `KeyNotFound` otherwise. **This method is not `@nogc`**.

Info methods:

* `length()` - current number of keys in table.
* `size()` - currents size of the table. Size can change when table is overflowed (more than 4/5 of the table is allocated for keys).

Iterators:
* `byKey()` - returns range of all keys in table without any order. Unstable - become invalid if you add/remove keys while use byKey range.
* `byValue()` - returns range of all values in table without any order. Unstable - become invalid if you add/remove keys while use byValue range.
* `byPair()` - returns range of all key-value pairs in table without any order. Unstable - invalid if you add/remove keys while use byPair range. Range elements are named tuples with `.key` and `.value` items.

## CompressedList ##

`CompressedList` is safe and nogc `unrolled` list. Instead of allocating for each item, unrolled lists allocate chunks for some number of items. Within each chunk items behave like array - insertion and deletion shift items within the chunk (overflowing to neghbor chunks if required).

This implementation avoid shifting and overflowing using prev and next links within chunks. So it is more like double-linked list within chunks instead of array.

It support (unstable) pointer to items inside list. Pointer is actually a index of item inside a chunk and pointer to chunk itself.

Update methods.

* `insertFront(v)` - create front item in the list.
Returns `pointer` to new item.
* `popFront()` - pop front item from list.
* `insertBack(v)` - create back item in the list.
Returns `pointer` to new item.
* `popBack()` - pop back item from list.
* `remove(ptr)` - remove item using item pointer. This method marked as @system as it is unstable, so that you have to know what you do.
* `clear()` - remove all entries from list.

Lookup methods.
* `front()` - content of the first item in the list.
* `back()` - contents of the last item in the list.

Info methods
* `length()` - number of items in list.
* `empty()` - `true` if list is empty.