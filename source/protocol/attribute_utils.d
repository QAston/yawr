module protocol.attribute_utils;

import std.typetuple;
import std.algorithm;
import std.traits;

import protocol.packet;

template isModule(alias T) {
    enum isModule = T.stringof.startsWith("module ");
}

template isSymbol(T) {
    enum isSymbol = false;
}

template isSymbol(alias T) {
    enum isSymbol = true;
}

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
            //pragma(msg, names[0]);
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

