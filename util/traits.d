module util.traits;

import std.typetuple;
import std.algorithm;
import std.traits;

/+
 + Tests whenever there's versionString version defined
 +/
mixin template Versions()
{
    template isDefined(string versionString)
    {
        mixin ("version(" ~ versionString ~ ") enum isDefined = true; else enum isDefined = false;");
    }
}

/+
 + Retuns base type of an enum
 +/
template EnumBase(T)
{
    static if (is(T BASE == enum))
    {
        alias BASE EnumBase;
    }
    else
    {
        static assert (false, "Type T is not an enum!");
    }
}

/++
+ casts enum type to it's base type
+/
auto toEnumBase(T)(T t)
{
    return cast(EnumBase!T)t;
}

unittest {
    enum Test {
        T1 = 1,
        T2 = 2,
    }
    static assert(is(EnumBase!(Test) == int));
}

private {
    mixin Versions versionsTest;

    version = util_traits_is_version_test_true;
    static assert (versionsTest.isDefined!"util_traits_is_version_test_true" && !versionsTest.isDefined!"util_traits_is_version_test_false");
}

template isModule(alias T) {
    enum isModule = T.stringof.startsWith("module ");
}

static assert(isModule!(util.traits));
static assert(!isModule!isModule);

/+
 + Checks whenever given parameter is a symbol
 +/
template isSymbol(T) {
    enum isSymbol = false;
}

template isSymbol(alias T) {
    enum isSymbol = true;
}

static assert(isSymbol!isSymbol);
static assert(!isSymbol!uint);

/+
 + Returns symbol members of a module T matching given predicate
 +/
template ModuleMembersMatching(alias T, alias PRED) if (isModule !T) {
    alias TypeTuple!(FilterMembers!(__traits(allMembers, T)))
        ModuleMembersMatching;

    template isMatching(string name)
    {
        static if (!isSymbol!(__traits(getMember, T,name)))
            enum isMatching = false;
        else
            enum isMatching = PRED!(__traits(getMember, T,name));
    }

    template FilterMembers(names...)
    {
        static if (names.length > 0) {
            static if (isMatching!(names[0])) {
                alias TypeTuple!(
                                 __traits(getMember, T, names[0]),
                                 FilterMembers!(names[1 .. $])
                                     ) FilterMembers;
            } else {
                alias TypeTuple!(
                                 FilterMembers!(names[1 .. $])
                                 ) FilterMembers;
            }
        } else {
            alias TypeTuple!() FilterMembers;
        }
    }
}

/// Returns sum of .sizeof of all fields in a struct
template MembersSize(T) if(is(T==struct))
{
    enum MembersSize = LoopMembers!(FieldTypeTuple!T);
    template LoopMembers(members...)
    {
        static if (members.length > 0) {
            enum LoopMembers = members[0].sizeof + LoopMembers!(members[1..$]);
        }
        else {
            enum LoopMembers = 0;
        }
    }
}

/// Returns sum of .sizeof of all fields in a struct recursively
template RepresentationMembersSize(T) if(is(T==struct))
{
    enum RepresentationMembersSize = LoopMembers!(RepresentationTypeTuple!T);
    template LoopMembers(members...)
    {
        static if (members.length > 0) {
            enum LoopMembers = members[0].sizeof + LoopMembers!(members[1..$]);
        }
        else {
            enum LoopMembers = 0;
        }
    }
}

///
unittest {
    struct TestType {
        ubyte a;
        ushort b;
    }
    struct TestTypeAligned {
        align(1):
        ubyte a;
        ushort b;
    }
    align(1) struct AlignedTestTypeAligned {
        align(1):
        ubyte a;
        ushort b;
    }
    struct SuperTestType {
        ubyte a;
        TestType b;
        TestType c;
    }
    struct SuperTestTypeAligned {
        align(1):
        ubyte a;
        TestType b;
        TestType c;
    }
    struct SuperTestTypeAlignedAligned {
        align(1):
        ubyte a;
        TestTypeAligned b;
        TestTypeAligned c;
    }
    struct SuperAlignedTestTypeAlignedAligned {
        align(1):
        ubyte a;
        AlignedTestTypeAligned b;
        AlignedTestTypeAligned c;
    }
    static assert(MembersSize!TestType == 3);
    static assert(MembersSize!SuperTestType == 9);
    static assert(RepresentationMembersSize!SuperTestType == 7);
    static assert(MembersSize!SuperTestTypeAligned == 9);
    static assert(RepresentationMembersSize!SuperTestTypeAlignedAligned == 7);
    static assert(MembersSize!SuperTestTypeAlignedAligned == 9);
    static assert(RepresentationMembersSize!SuperAlignedTestTypeAlignedAligned == 7);
    static assert(MembersSize!SuperAlignedTestTypeAlignedAligned == 7);
    static assert(MembersSize!TestType == RepresentationMembersSize!TestType);
}

/++
+ evaluates to TypeTuple of attributes of a symbol
+/
template Attributes (alias symbol)
{
    static if (!__traits(compiles, __traits(getAttributes, symbol)))
        alias TypeTuple!() Attributes;

    else
        alias TypeTuple!(__traits(getAttributes, symbol)) Attributes;
}