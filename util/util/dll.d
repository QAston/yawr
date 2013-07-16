module util.dll;

/+
 + Fixes issues with importing shared library interfaces which have ModuleInfo symbols
 +/
string importDynamically(alias importedModule)()
{
	return "extern(C) int D" ~ importedModule.mangleof ~ "12__ModuleInfoZ;";
}

const(char)* mangledSymbol(alias symbol)()
{
    static assert(((symbol.mangleof) ~ "\0").length < 128, "longer names won't be available in a library!!!");
    return ((symbol.mangleof) ~ "\0").ptr;
}