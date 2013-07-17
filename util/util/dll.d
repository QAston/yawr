module util.dll;

/+
 + Fixes issues with importing shared library interfaces which have ModuleInfo symbols
 +/
string importDynamically(alias importedModule)()
{
	return "extern(C) int D" ~ importedModule.mangleof ~ "12__ModuleInfoZ;";
}

unittest {
    // line below should give linker error as it shadows declaration of this moduleinfo
    //mixin (importDynamically!(util.dll));
}

/+
 + Mangles symbol according to DLL rules
 +/
const(char)* mangledSymbol(alias symbol)()
{
    static assert((symbol.mangleof) != "v", "Incomplete symbol - won't be available in a library");
    static assert(((symbol.mangleof) ~ "\0").length < 128, "Too long symbol name - won't be available in a library");
    return ((symbol.mangleof) ~ "\0").ptr;
}

unittest {
    struct A {
    }
    static assert(mangledSymbol!A == "S4util3dll15__unittestL26_2FZv1A\0");
}