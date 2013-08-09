/+
 + This module provides game version related defines, like client build/patch numbers.
 +/
module wowdefs.wow_versions;

import std.traits;
import std.datetime;
import std.typecons;

/+
 + Client build numbers which are used to identify versions of the game
 +/
enum WowVersion : ushort {
    Undefined = 0,

	V1_12_1_5875 = 5875,

	V2_0_1_6180 = 6180,
	V2_0_3_6299 = 6299,
	V2_0_6_6337 = 6337,
	V2_1_0_6692 = 6692,
	V2_1_1_6739 = 6739,
	V2_1_2_6803 = 6803,
	V2_1_3_6898 = 6898,
	V2_2_0_7272 = 7272,
	V2_2_2_7318 = 7318,
	V2_2_3_7359 = 7359,
	V2_3_0_7561 = 7561,
	V2_3_2_7741 = 7741,
	V2_3_3_7799 = 7799,
	V2_4_0_8089 = 8089,
	V2_4_1_8125 = 8125,
	V2_4_2_8209 = 8209,
	V2_4_3_8606 = 8606,

	V3_0_2_9056 = 9056,
	V3_0_3_9183 = 9183,
	V3_0_8_9464 = 9464,
	V3_0_8a_9506 = 9506,
	V3_0_9_9551 = 9551,
	V3_1_0_9767 = 9767,
	V3_1_1_9806 = 9806,
	V3_1_1a_9835 = 9835,
	V3_1_2_9901 = 9901,
	V3_1_3_9947 = 9947,
	V3_2_0_10192 = 10192,
	V3_2_0a_10314 = 10314,
	V3_2_2_10482 = 10482,
	V3_2_2a_10505 = 10505,
	V3_3_0_10958 = 10958,
	V3_3_0a_11159 = 11159,
	V3_3_3_11685 = 11685,
	V3_3_3a_11723 = 11723,
	V3_3_5_12213 = 12213,
	V3_3_5a_12340 = 12340,

	V4_0_1_13164 = 13164,
	V4_0_1a_13205 = 13205,
	V4_0_3_13329 = 13329,
	V4_0_6_13596 = 13596,
	V4_0_6a_13623 = 13623,
	V4_1_0_13914 = 13914,
	V4_1_0a_14007 = 14007,
	V4_2_0_14333 = 14333,
	V4_2_0a_14480 = 14480,
	V4_2_2_14545 = 14545,
	V4_3_0_15005 = 15005,
	V4_3_0a_15050 = 15050,
	V4_3_2_15211 = 15211,
	V4_3_3_15354 = 15354,
	V4_3_4_15595 = 15595,
	V5_0_4_16016 = 16016,
	V5_0_5_16048 = 16048,
	V5_0_5a_16057 = 16057,
	V5_0_5b_16135 = 16135,
	V5_1_0_16309 = 16309,
	V5_1_0a_16357 = 16357
}

private immutable Tuple!(WowVersion, Date)[] wowVersionDates = [
    tuple(WowVersion.V1_12_1_5875 , Date(2006, 9, 26)), 
    tuple(WowVersion.V2_0_1_6180 , Date(2006, 12, 5)),
    tuple(WowVersion.V2_0_3_6299 , Date(2007, 1, 9)),
    tuple(WowVersion.V2_0_6_6337 , Date(2007, 1, 23)),
    tuple(WowVersion.V2_1_0_6692 , Date(2007, 5, 22)),
    tuple(WowVersion.V2_1_1_6739 , Date(2007, 6, 5)),
    tuple(WowVersion.V2_1_2_6803 , Date(2007, 6, 19)),
    tuple(WowVersion.V2_1_3_6898 , Date(2007, 7, 10)),
    tuple(WowVersion.V2_2_0_7272 , Date(2007, 9, 25)),
    tuple(WowVersion.V2_2_2_7318 , Date(2007, 10, 3)),
    tuple(WowVersion.V2_2_3_7359 , Date(2007, 10, 9)),
    tuple(WowVersion.V2_3_0_7561 , Date(2007, 11, 13)),
    tuple(WowVersion.V2_3_2_7741 , Date(2008, 1, 8)),
    tuple(WowVersion.V2_3_3_7799 , Date(2008, 1, 22)),
    tuple(WowVersion.V2_4_0_8089 , Date(2008, 3, 25)),
    tuple(WowVersion.V2_4_1_8125 , Date(2008, 4, 1)),
    tuple(WowVersion.V2_4_2_8209 , Date(2008, 5, 13)),
    tuple(WowVersion.V2_4_3_8606 , Date(2008, 7, 15)),

    tuple(WowVersion.V3_0_2_9056 , Date(2008, 10, 14)),
    tuple(WowVersion.V3_0_3_9183 , Date(2008, 11, 4)),
    tuple(WowVersion.V3_0_8_9464 , Date(2009, 1, 20)),
    tuple(WowVersion.V3_0_8a_9506 , Date(2009, 1, 27)),
    tuple(WowVersion.V3_0_9_9551 , Date(2009, 2, 10)),
    tuple(WowVersion.V3_1_0_9767 , Date(2009, 4, 14)),
    tuple(WowVersion.V3_1_1_9806 , Date(2009, 4, 21)),
    tuple(WowVersion.V3_1_1a_9835 , Date(2009, 4, 28)),
    tuple(WowVersion.V3_1_2_9901 , Date(2009, 5, 13)),
    tuple(WowVersion.V3_1_3_9947 , Date(2009, 6, 2)),
    tuple(WowVersion.V3_2_0_10192 , Date(2009, 8, 4)),
    tuple(WowVersion.V3_2_0a_10314 , Date(2009, 8, 19)),
    tuple(WowVersion.V3_2_2_10482 , Date(2009, 9, 22)),
    tuple(WowVersion.V3_2_2a_10505 , Date(2009, 9, 25)),
    tuple(WowVersion.V3_3_0_10958 , Date(2009, 12, 2)),
    tuple(WowVersion.V3_3_0a_11159 , Date(2009, 12, 14)),
    tuple(WowVersion.V3_3_3_11685 , Date(2010, 3, 23)),
    tuple(WowVersion.V3_3_3a_11723 , Date(2010, 3, 26)),
    tuple(WowVersion.V3_3_5_12213 , Date(2010, 6, 22)),
    tuple(WowVersion.V3_3_5a_12340 , Date(2010, 6, 29)),

    tuple(WowVersion.V4_0_1_13164 , Date(2010, 10, 12)),
    tuple(WowVersion.V4_0_1a_13205 , Date(2010, 10, 26)),
    tuple(WowVersion.V4_0_3_13329 , Date(2010, 11, 23)),
    tuple(WowVersion.V4_0_6_13596 , Date(2011, 2, 8)),
    tuple(WowVersion.V4_0_6a_13623 , Date(2011, 2, 11)),
    tuple(WowVersion.V4_1_0_13914 , Date(2011, 4, 26)),
    tuple(WowVersion.V4_1_0a_14007 , Date(2011, 5, 5)),
    tuple(WowVersion.V4_2_0_14333 , Date(2011, 6, 28)),
    tuple(WowVersion.V4_2_0a_14480 , Date(2011, 9, 8)),
    tuple(WowVersion.V4_2_2_14545 , Date(2011, 9, 30)),
    tuple(WowVersion.V4_3_0_15005 , Date(2011, 11, 30)),
    tuple(WowVersion.V4_3_0a_15050 , Date(2011, 12, 2)),
    tuple(WowVersion.V4_3_2_15211 , Date(2012, 1, 31)),
    tuple(WowVersion.V4_3_3_15354 , Date(2012, 2, 28)),
    tuple(WowVersion.V4_3_4_15595 , Date(2012, 4, 17)),
    tuple(WowVersion.V5_0_4_16016 , Date(2012, 8, 28)),
    tuple(WowVersion.V5_0_5_16048  , Date(2012, 9, 11)),
    tuple(WowVersion.V5_0_5a_16057 , Date(2012, 9, 13)),
    tuple(WowVersion.V5_0_5b_16135 , Date(2012, 10, 14)),
    tuple(WowVersion.V5_1_0_16309 , Date(2012, 11, 13)),
    tuple(WowVersion.V5_1_0a_16357 , Date(2012, 12, 3))];

/+
 + Returns WowVersion which was "current" at a given date
 +/
WowVersion getWowVersion(in Date date)
{
    if (date < wowVersionDates[0][1])
        return WowVersion.Undefined;

    for (auto i = 1; i < wowVersionDates.length; i++)
        if (wowVersionDates[i][1] > date)
            return wowVersionDates[i - 1][0];

    return wowVersionDates[$-1][0];
}

///
unittest {
    import util.test;
    import std.traits;
    mixin (test!("getWowVersion"));
    assert(getWowVersion(Date(2012, 12, 3)) == WowVersion.V5_1_0a_16357);
    assert(getWowVersion(Date(2010, 8, 29)) == WowVersion.V3_3_5a_12340);
    assert(getWowVersion(Date(2003, 12, 3)) == WowVersion.Undefined);
}

/+
 + Major versions - each expansion introduced a new version of the game
 + Not refered to as expansion however, as client doesn't have to have MoP expansion to use MajorWowVersion 5
 +/
enum MajorWowVersion : ubyte {
    Alpha = 0,
    Vanilla = 1,
    TBC = 2,
    WotLK = 3,
    Cataclysm = 4,
    MoP = 5,
}

/+
 + Represents official client version numeration, eg 3.3.5a
 +/
struct PatchInfo
{
    MajorWowVersion major;
    ubyte minor;
    ubyte bugfix;
    char hotfix = ' ';
}

private static PatchInfo[WowVersion] builds;

static this ()
{
    import std.conv;
    import std.string;
    import std.array;
    import std.ascii;
    foreach (wowVersion;EnumMembers!WowVersion)
    {
        if (wowVersion != WowVersion.Undefined)
        {
            assert(wowVersion !in builds);
            PatchInfo patch;
            string ver = wowVersion.to!string()[1..$];

            string[] subVersions = ver.split("_");

            patch.major = (subVersions[0].to!ubyte).to!MajorWowVersion;
            patch.minor = subVersions[1].to!ubyte;
            patch.bugfix = subVersions[2][0..1].to!ubyte;
            if (subVersions[2].length > 1)
            {
                assert(subVersions[2][1].isAlpha());
                patch.hotfix = subVersions[2][1];
            }
            assert(subVersions[3].to!ushort == wowVersion);
            builds[wowVersion] = patch;
        }
    }
}

/+
 + Returns PatchInfo for a given version_
 + Returns null when version not defined
 +/
PatchInfo* getPatchInfo(WowVersion version_)
{
    return version_ in builds;
}

///
unittest {
    assert(getPatchInfo(WowVersion.Undefined) == null);
    assert(*getPatchInfo(WowVersion.V2_2_3_7359) == PatchInfo(MajorWowVersion.TBC, 2, 3));
    assert(*getPatchInfo(WowVersion.V3_3_5a_12340) == PatchInfo(MajorWowVersion.WotLK, 3, 5, 'a'));
}
