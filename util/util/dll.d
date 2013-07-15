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
    return ((symbol.mangleof)[1..$] ~ "\0").ptr;
}