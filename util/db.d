module util.db;

/++
+ Returns a comma separated list of all fields from a struct of given type T
+/
string formatSqlColumnList(T)() pure
{
    // make sure it's only a simple struct
    static assert(__traits(allMembers, T).length == T.tupleof.length);
    import std.array;
    auto app = appender!(string);
    bool first = true;
    foreach (a; __traits(allMembers, T))
    {
        if (first)
        {
            first = false;
        }
        else
        {
            app.put(", ");
        }
        app.put(a);
    }
    return app.data();
}

///
unittest {

    struct Test {
        uint a;
        ushort b;
    }
    
    assert(formatSqlColumnList!(Test) == "a, b");
}