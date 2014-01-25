module util.dbc;

import std.stdio;
import core.memory;
import std.array;
import util.traits;
import std.traits;
import core.stdc.string;
import util.binary;
import std.exception;
import std.typetuple;

/// UDA, defines number of bytes to skip before a field in DBC structure
struct SkipBytes
{
    uint bytes;
    this(uint bytes)
    {
        this.bytes = bytes;
    }
}

/++
+ returns an array or an associative array of STRUCTs loaded from filename file
+ STRUCT should be a structure without indirections (except string types - those are handled by dbc format)
+ STRUCT must have "id" field which will be used as index in returned AA
+/
auto loadDbc(STRUCT)(string filename)
{
    File file = File(filename, "rb");
    return loadDbc!STRUCT(file);
}

/// ditto
auto loadDbc(STRUCT)(File file)
in {
    assert(file.isOpen);
}
body
{
    static assert(__traits(allMembers, STRUCT).length == STRUCT.tupleof.length);

    FILE* f = file.getFP();

    uint header, recordCount, fieldCount, recordSize, stringSize;

    if (fread(&header, 4, 1, f) != 1)                        // identifier
        throw new DbcException("Invalid dbc file");

    if (header != 0x43424457)                                //'WDBC'
        throw new DbcException("Invalid dbc file");

    if (fread(&recordCount, 4, 1, f) != 1)                   // Number of records
        throw new DbcException("Invalid dbc file");

    if (fread(&fieldCount, 4, 1, f) != 1)                    // Number of fields
        throw new DbcException("Invalid dbc file");

    if (fread(&recordSize, 4, 1, f) != 1)                    // Size of a record
        throw new DbcException("Invalid dbc file");

    if (fread(&stringSize, 4, 1, f) != 1)                    // String size
        throw new DbcException("Invalid dbc file");

    auto records = uninitializedArray!(ubyte[])(recordSize * recordCount);
    scope(exit)
    {
        GC.free(records.ptr);
    }
    auto strings = uninitializedArray!(char[])(stringSize);

    if (fread(records.ptr, recordSize * recordCount, 1, f) != 1)
        throw new DbcException("Error while reading records from file");

    if (fread(strings.ptr, stringSize, 1, f) != 1)
        throw new DbcException("Error while reading strings from file");

    STRUCT[typeof(STRUCT.id)] ret;

    foreach(i;0..recordCount)
    {
        auto s = readDbcEntry!STRUCT(records[recordSize*i .. recordSize*(i+1)], strings);
        ret[s.id] = s;
    }
    ret.rehash();
    return ret;
}

private STRUCT readDbcEntry(STRUCT)(ubyte[] data, char[] strings)
{
    STRUCT dbcEntry;
    foreach(string field; __traits(allMembers, STRUCT))
    {
        readField!(field)(dbcEntry, data, strings);
    }
    return dbcEntry;
}

private enum isSkipBytes(alias val) = is(typeof(val) == SkipBytes);

private void readField(string field, STRUCT)(STRUCT entry, ref ubyte[] data, char[] strings)
{
    alias bytesToSkip = Filter!(isSkipBytes, Attributes!(mixin(`STRUCT.`~field~``)));
    foreach(bytes; bytesToSkip)
    {
        data = data[bytes.bytes .. $];
    }
    readFieldValue(mixin(`entry.`~field), data, strings);
}

private void readFieldValue(TYPE)(ref TYPE field, ref ubyte[] data, const char[] strings)
{
    static if (isStaticArray!TYPE)
    {
        foreach(i; 0..TYPE.length)
        {
            readFieldValue(field[i], data, strings);
        }
    }
    else static if (isSomeString!TYPE)
    {
        enum size = uint.sizeof;
        uint strIndex;
        auto tmp = asByteArray(strIndex);
        tmp = data[0..size];
        data = data[size..$];
        field = assumeUnique(strings[strIndex.. strlen(strings.ptr + strIndex)]);
    }
    else static if (!hasIndirections!TYPE)
    {
        enum size = TYPE.sizeof;
        auto tmp = asByteArray(field);
        tmp = data[0..size];
        data = data[size..$];
    }
    else
    {
        static assert(false, "not implemented dbc field type ("~TYPE.stringof~")");
    }
}

class DbcException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

struct Test {
    @SkipBytes(3)
    uint id;
    @SkipBytes(6)
    string str;
    string[5] fiveStr;
    SubStruct[4] subs;
}

struct SubStruct {
    uint a;
}

unittest {
    static assert(__traits(compiles, loadDbc!Test("test.dbc")));
}