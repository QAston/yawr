module protocol.stream_utils;

import vibe.core.stream;

import std.bitmanip;
import std.system;

/+
 + Reads Integral/Char/Boolean/FloatingPoint from an InputStream
 +/
T sread(T, Endian endianness = Endian.littleEndian)(InputStream s)
	if (isIntegral!T || isSomeChar!T || isBoolean!T || isFloatOrDouble!T)
{
	ubyte[T.sizeof] array;
	ubyte[] buffer = array[];
	s.read(buffer);
	return buffer.read!(T, endianness)();
}

/+
 + Peeks Integral/Char/Boolean/FloatingPoint from an InputStream
 +/
T speek(T, Endian endianness = Endian.littleEndian)(InputStream s)
	if (isIntegral!T || isSomeChar!T || isBoolean!T || isFloatOrDouble!T)
in
{
	assert(s.leastSize >= T.sizeof);
}
body
{
	const(ubyte)[] buffer = s.peek();
	return buffer.read!(T, endianness)();
}

/+
 + Peeks an array of bytes from InputStream
 +/
const(ubyte[]) peekAll(InputStream s, size_t length = size_t.max)
in
{
	assert(length == size_t.max || s.leastSize >= length);
}
body
{
	auto buffer = s.peek();
	if (length != size_t.max)
		buffer = buffer[0..length];

	return buffer;
}

unittest {
	string val = "UTF";
	import vibe.stream.memory;
	
	auto stream = new MemoryStream(cast(ubyte[])val);
	assert(stream.peekAllUTF8 == val);
}

/+
 + Peeks a string from InputStream
 +/
string peekAllUTF8(InputStream s, size_t length = size_t.max)
in
{
	assert(length == size_t.max || s.leastSize >= length);
}
body
{
	return vibe.utils.string.sanitizeUTF8(peekAll(s, length));
}

/+
 + Writes Integral/Char/Boolean/FloatingPoint to an InputStream
 +/
void swrite(T, Endian endianness = Endian.littleEndian)(OutputStream s, T value)
	if (isIntegral!T || isSomeChar!T || isBoolean!T || isFloatOrDouble!T)
{
	ubyte[T.sizeof] array;
	ubyte[] buffer = array[];
	buffer.write!(T, endianness)(value, 0);
	s.write(buffer);
}

unittest {
	import vibe.stream.memory;

	void test(T)(T val)
	{
		ubyte[T.sizeof] array;
		ubyte[] buffer = array[];
		
		auto stream = new MemoryStream(buffer);
		stream.swrite!T(val);
		stream.seek(0);
		assert(stream.sread!T == val);
	}

	test!ulong(100000);
	test!long(900);
	test!uint(5);
	test!int(-5);
	test!short(7);
	test!byte(7);
	test!float(1.7);
	test!double(32.6);
	test!bool(true);
}

unittest {
	import vibe.stream.memory;
	import std.exception;
	void test(T)(T val)
	{
		ubyte[T.sizeof] array;
		ubyte[] buffer = array[];
		
		auto stream = new MemoryStream(buffer);
		stream.swrite!T(val);
		stream.swrite!T(val);
	}

	assertThrown(test!uint(4));
	assertThrown(test!int(-300));
	assertThrown(test!byte(117));
	assertThrown(test!ubyte(250));
}

unittest {
	import vibe.stream.memory;

	void test(T)(T val)
	{
		ubyte[T.sizeof] array;
		ubyte[] buffer = array[];
		
		auto stream = new MemoryStream(buffer);
		stream.swrite!T(val);
		stream.seek(0);
		assert(stream.speek!T == val);
	}

	test!uint(5);
	test!int(-5);
	test!short(7);
	test!byte(7);
	test!float(1.7);
	test!double(32.6);
	test!bool(true);
}
