module util.conf;

/// redirect to vibe module
public import vibe.core.args;

/++
+ Loads a config option into an imut variable
+/
shared void loadOpt(T)(string optName, immutable ref T loadTo, string description)
{
    getOption(optName, cast(T*)&loadTo, description);
}