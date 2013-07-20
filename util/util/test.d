module util.test;

string test(string name)() {
    return `import std.stdio;
        std.stdio.writefln(__FILE__~" line: %d"~": ` ~ name ~ ` test", __LINE__);
        scope(failure) std.stdio.writeln("failed");
        scope(success) std.stdio.writeln("success");`;
}

string test(alias name)() {
    
    import std.traits;
    return test!(fullyQualifiedName!name);
}