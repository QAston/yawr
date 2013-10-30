module util.string;

import core.stdc.string;
import std.string;

/++
+ Converts c string representation to d string
+/
inout(char)[] stringzToString(inout(char)* cString)
{
    if (cString is null)
        return null;
    size_t len = strlen(cString);
    return cString[0..len];
}

unittest {
    assert(stringzToString("asd".toStringz) == "asd");
    assert(stringzToString(null) is null);
}