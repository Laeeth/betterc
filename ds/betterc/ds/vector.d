/**
 * Betterc: Frequently used primitives suitable for use in the BetterC D subset.
 *
 * Copyright: Maxim Freck, 2018.
 * Authors:   Maxim Freck <maxim@freck.pp.ru>
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module betterc.ds.vector;

/*******
 * Dynamic Vector without Garbage Collection
 */
struct Vector(T)
{
	private import core.stdc.stdlib: malloc, realloc, free;
	private import core.stdc.string: memcpy, memmove;

	private struct Payload {
		T* arr;
		size_t length;
		size_t capacity;
		size_t initCap;

		size_t count;
		@disable this(this); // not copyable
	}

	private Payload* payload;

	/*******
	* Constructor
	*
	* Params:
	*  n = Initial vector capacity
	*/
	this (size_t n) nothrow @nogc
	{
		payload = (cast(Payload*)malloc(Payload.sizeof));
		payload.length = 0;
		payload.capacity = n;
		payload.initCap = n;
		payload.arr = (cast(T*)malloc(T.sizeof*n));
		payload.count = 1;
	}

	/*******
	* Constructor
	*
	* Params:
	*  src = Initial vector values
	*  n = Initial vector capacity
	*/
	this(T[] src, size_t n = 0) nothrow @nogc
	{

		payload = (cast(Payload*)malloc(Payload.sizeof));
		payload.length = 0;
		payload.initCap = n == 0 ? src.length : n;
		payload.capacity = payload.initCap;
		payload.arr = (cast(T*)malloc(T.sizeof*payload.capacity));
		payload.count = 1;

		push(src);
	}

	///ditto
	private this(Payload* src, size_t a, size_t b) nothrow @nogc
	{

		payload = (cast(Payload*)malloc(Payload.sizeof));
		payload.length = b - a;
		payload.initCap = src.initCap;
		payload.capacity = src.capacity;
		payload.arr = (cast(T*)malloc(T.sizeof*payload.length));
		payload.count = 1;
		memcpy(payload.arr, src.arr+a, payload.length);
	}

	///ditto
	this(this) nothrow @nogc
	{
		if (payload !is null)
			payload.count++;
	}

	///Ref. counting during structure assignment
	ref typeof(this) opAssign(ref typeof(this) rhs)
	{
		this.payload = rhs.payload;
		if (payload !is null)
			payload.count++;

		return this;
	}

	/*******
	* Destructor: frees all memory
	*/
	~this() nothrow @nogc
	{
		//TODO: call elements destructors if present
		if (payload !is null && --payload.count == 0) {
			free(payload.arr);
			free(payload);
		}
	}

	/*******
	* Shrinks vector
	*
	* Params:
	*  len = New vector size
	*/
	public ref typeof(this) shrink(size_t len = 0) nothrow @nogc
	{
		if (len < payload.length) payload.length = len;
		if (payload.length == 0 || payload.capacity/payload.length > 1) shrink_to_fit();
		return this;
	}

	/*******
	* Requests the removal of unused capacity.
	*
	*/
	public ref typeof(this) shrink_to_fit() nothrow @nogc
	{
		payload.capacity = payload.length == 0 ? payload.initCap : (payload.length * 3) / 2;
		payload.arr = (cast(T*)realloc(payload.arr, T.sizeof*payload.capacity));
		return this;
	}

	/*******
	* Clears entire vector
	*
	*/
	pragma(inline)
	public ref typeof(this) clear() nothrow @nogc
	{
		return shrink(0);
	}

	/*******
	* Erases nth vector element
	*
	* Params:
	*  n = Element number
	*/
	public ref typeof(this) erase(in size_t n) nothrow @nogc
	{
		if (n >= payload.length) return this;

		if (n == payload.length - 1) {
			payload.length--;
			return this;
		}

		payload.length--;
		memmove(payload.arr+n, payload.arr+n+1, payload.length - n);

		return this;
	}

	/*******
	* Trims the capacity of the vector to be the vector's current size.
	*/
	public ref typeof(this) trim()
	{
		payload.capacity = payload.length;
		payload.arr = (cast(T*)realloc(payload.arr, T.sizeof*payload.capacity));

		return this;
	}

	/*******
	* Returns: the current length of the vector
	*/
	public size_t length() const pure nothrow @nogc
	{
		return payload.length;
	}

	/*******
	* Returns: the current capacity of the vector
	*/
	public size_t capacity() pure nothrow @nogc
	{
		return payload.capacity;
	}

	/*******
	* The [] operator
	*/
	public auto ref T opIndex(in size_t id) pure nothrow @nogc
	{
		if (payload.length == 0) return T.init;
		return payload.arr[id>=payload.length ? payload.length - 1 : id];
	}

	/*******
	* Appends a value to the vector
	*
	* Params:
	*  rhs = The value to add
	*/
	public ref typeof(this) push(in T rhs) nothrow @nogc
	{
		payload.length++;
		if (payload.length > payload.capacity) grow();
		payload.arr[payload.length - 1] = rhs;

		return this;
	}

	///ditto
	public ref typeof(this) push(in T[] rhs) nothrow @nogc
	{
		foreach (v; rhs) push(v);
		return this;
	}

	///ditto
	public ref typeof(this) push(typeof(this) rhs) nothrow @nogc
	{
		foreach (v; rhs) push(v);
		return this;
	}

	private void grow() nothrow @nogc
	{
		payload.capacity = (payload.capacity * 3) / 2 + 1;
		payload.arr = (cast(T*)realloc(payload.arr, T.sizeof*payload.capacity));
	}

	/*******
	* Removes the last element from the vector
	*/
	public void pop() nothrow @nogc
	{
		if (payload.length > 0) payload.length--;
	}

	/*******
	* Appends a value to the vector using << operator
	*
	* Params:
	*  rhs = The value to add
	*/
	pragma(inline)
	public ref typeof(this) opBinary(string op)(in T rhs) nothrow @nogc if (op == "<<")
	{
		return push(rhs);
	}

	///ditto
	pragma(inline)
	public ref typeof(this) opBinary(string op)(in T[] rhs) nothrow @nogc if (op == "<<")
	{
		return push(rhs);
	}

	///ditto
	pragma(inline)
	public ref typeof(this) opBinary(string op)(typeof(this) rhs) nothrow @nogc if (op == "<<")
	{
		return push(rhs);
	}


	/*******
	* The $ operator returns the length of the vector
	*/
	size_t opDollar() nothrow @nogc
	{
		return payload.length;
	}

	/*******
	* The [a..b] operator returns the slice of the vector
	*
	* Returns: a new vector containing values from a to b
	*/
	public typeof(this) opSlice(size_t a, size_t b) nothrow @nogc
	{
		if (a > b) {
			immutable c = b;
			b = a;
			a = c;
		}
		if (a > payload.length) a = payload.length;
		if (b > payload.length) b = payload.length;

		return typeof(this)(payload, a, b);
	}


	/*******
	* This method is used in foreach()
	*/
	int opApply(scope int delegate(ref T) nothrow @nogc dg) nothrow @nogc
	{
		int result = 0;

		foreach (size_t i; 0 .. payload.length) {
			result = dg(payload.arr[i]);
			if (result) break;
		}

		return result;
	}

	///ditto
	int opApply(scope int delegate(ref size_t, ref T) nothrow @nogc dg) nothrow @nogc
	{
		int result;

		foreach (size_t i; 0 .. payload.length) {
			result = dg(i, payload.arr[i]);
			if (result) break;
		}

		return result;
	}

	/*******
	* Returns: the pointer to the underlying vector
	*/
	T* ptr() pure nothrow @nogc
	{
		return payload.arr;
	}
}
