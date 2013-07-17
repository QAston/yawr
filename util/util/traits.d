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