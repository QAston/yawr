module util.wow_version;

public import util.wow_versions;

import std.traits, std.typetuple, std.typecons;

import util.traits;

private {
    import std.conv;

    mixin Versions versions;

    immutable string versionPrefix = "WowVersion";


    template checkVersion(alias name)
    {
        enum checkVersion = versions.isDefined!(versionPrefix ~name.to!string());
    }
    alias TypeTuple!(Filter!(checkVersion, EnumMembers!WowVersion)) definedWowVersions;

    static assert(definedWowVersions.length != 0, "Undefined WowVersion version, please specify a version in build options like --version=WowVersionV4_3_4_15595");
    static assert(definedWowVersions.length <= 1, "Too many WowVersion versions defined, please specify only one wow version per build");
}

enum wowVersion = definedWowVersions[0];