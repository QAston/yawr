/+
 + This module provides a Guid class
 + Guid is an identifier used both on client and on server side to uniquely identify objects
 + Guid stands for Globally Unique identifier, but there are various scopes at which Guid is unique: 
 +  - Universe - guid refers to the same object on all servers
 +  - Realm - guid is unique in a current realm(server)
 +  - Map - guid is unique on a given map, but not on whole ream
 + null is a valid guid - stands for no guid in various places (has all-zeros binary representation)
 +/
module wowdefs.guid;

import wowdefs.wow_version;

import util.test;

import std.bitmanip;

/+
 + Byte signatures identifying different kinds of guids, parts of their binary representation
 +/
enum GuidType : ushort
{
    // used only serverside:
    None            = 0xFFF, 
    // used clientside:
    // universal ids
    BattleGround    = 0x1F1, // indentifies type of battleground?
    MOTransport     = 0x1FC, // all transports have this flag in 434 and 335

    // realm ids
    Player          = 0x000,
    Item            = 0x400, // also container - indistinguishable
    Instance        = 0x1F4,
    Group           = 0x1F5,
    Guild           = 0x1FF,

    // map id's
    // second digit has various values
    DynObject       = 0xF00, // corpses share pool with dynamic objects
    GameObject      = 0xF01,
    Transport       = 0xF02, // didn't find any in 335 and 434
    Creature        = 0xF03,
    Pet             = 0xF04,
    Vehicle         = 0xF05,
}

/+
 + Returns GuidType of the binary representation
 + Doesn't check for enum value validity - use with caution
 +/
private GuidType getType(ulong guid)
{
    if (guid == 0)
        return GuidType.None;
    ushort typeMarker = guid >>> 52;
    ushort shortMarker = typeMarker & 0xF00;
    if (shortMarker == GuidType.Player || shortMarker == GuidType.Item)
        return cast(GuidType)shortMarker;
    if (shortMarker == 0xF00)
        return cast(GuidType)(typeMarker & 0xF0F);
    return cast(GuidType)(typeMarker);
}

unittest {
    mixin (test!"getType");
    assert (getType(0) == GuidType.None);
    assert (getType(0x4280000000000004) == GuidType.Item);
    assert (getType(0x4001230000000004) == GuidType.Item);
    assert (getType(0x0000000000000123) == GuidType.Player);
    assert (getType(0x0123450000000123) == GuidType.Player);
    assert (getType(0x1F134E2342342123) == GuidType.BattleGround);
    assert (getType(0x1FC34E2342342123) == GuidType.MOTransport);
    assert (getType(0x1F43450000000123) == GuidType.Instance);
    assert (getType(0x1F534E2342342123) == GuidType.Group);
    assert (getType(0x1FF34E2342342123) == GuidType.Guild);
    assert (getType(0xF1034E2342342123) == GuidType.DynObject);
    assert (getType(0xF3034E2342342123) == GuidType.DynObject);
    assert (getType(0xF1134E2342342123) == GuidType.GameObject);
    assert (getType(0xF3134E2342342123) == GuidType.GameObject);
    assert (getType(0xF1234E2342342123) == GuidType.Transport);
    assert (getType(0xF3234E2342342123) == GuidType.Transport);
    assert (getType(0xF1334E2342342123) == GuidType.Creature);
    assert (getType(0xF3334E2342342123) == GuidType.Creature);
    assert (getType(0xF1434E2342342123) == GuidType.Pet);
    assert (getType(0xF3434E2342342123) == GuidType.Pet);
    assert (getType(0xF1534E2342342123) == GuidType.Vehicle);
    assert (getType(0xF3534E2342342123) == GuidType.Vehicle);
}

class GuidException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}
/+
 + Creates a guid object out of binary representation
 + Can return null - it's a valid guid value
 + throws GuidException if creation fails
 +/
immutable (Guid) create(ulong guid)
{
    import std.traits;
    import std.conv;
    static string getSwitchContent() {
        string s;
        foreach(T; EnumMembers!GuidType) {
            if (T != GuidType.None)
            {
                s ~= "case " ~ T.stringof;
                s ~= ": return new immutable(TypedGuid!("~ T.to!string ~"))(TypedGuid!("~ T.to!string ~").Representation(guid));";
            }
        }

        return s;
    }

    auto type = getType(guid);
    try {
        final switch (type) with (GuidType)
        {
            case None:
                return null;
            mixin(getSwitchContent());
        }
    }
    catch (core.exception.SwitchError error)
    {
        throw new GuidException("Incorrect guidType "~ (cast(uint)type).to!string ~"- could not create a Guid object");
    }
}

unittest {
    mixin (test!((create)));
    assert (create(0) is null);
    assert (create(0x4280000000000004).type == GuidType.Item);
    assert (create(0x4001230000000004).type == GuidType.Item);
    assert (create(0x0000000000000123).type == GuidType.Player);
    assert (create(0x0123450000000123).type == GuidType.Player);
    assert (create(0x1F134E2342342123).type == GuidType.BattleGround);
    assert (create(0x1FC34E2342342123).type == GuidType.MOTransport);
    assert (create(0x1F43450000000123).type == GuidType.Instance);
    assert (create(0x1F534E2342342123).type == GuidType.Group);
    assert (create(0x1FF34E2342342123).type == GuidType.Guild);
    assert (create(0xF1034E2342342123).type == GuidType.DynObject);
    assert (create(0xF1134E2342342123).type == GuidType.GameObject);
    assert (create(0xF5234E2342342123).type == GuidType.Transport);
    assert (create(0xF7334E2342342123).type == GuidType.Creature);
    assert (create(0xF1434E2342342123).type == GuidType.Pet);
    assert (create(0xF1534E2342342123).type == GuidType.Vehicle);
    assert (create(0xF1634E2342342123).type == GuidType.Vehicle);
}

/+
 + Base interface for Guid classes
 +/
interface Guid {
    @property ulong binary() immutable;
    @property ulong id() immutable;
    @property GuidType type() immutable;
}

/// a marker interface for Guid valid at a map scope
interface MapGuid : RealmGuid, Guid {
}

/// a marker interface for Guid valid at a realm scope
interface RealmGuid : UniversalGuid, Guid {
}

/// a marker interface for Guid valid at a universal scope
interface UniversalGuid : Guid {
}

/// common interface for guids with entry
interface EntryGuid : Guid {
    @property uint entry() immutable;
}

/// Common boilerplate of TypeGuids factored out
mixin template TypeGuidCommon(GuidType guidType)
{
    immutable {
        Representation guid;
        alias guid this;

        @property ulong binary()
        {
            return guid.tupleof[0];
        }
        @property GuidType type()
        {
            return guidType;
        }
        @property ulong id()
        {
            return guid.id;
        }
    }
}

immutable final class TypedGuid(GuidType guidType) if (guidType == GuidType.Player || guidType == GuidType.Item)
        : RealmGuid
{
    struct Representation {
        mixin(bitfields!( ubyte, "typeMarker", 4, ubyte, "realmId", 8, ulong, "id", 52));
    }
    mixin TypeGuidCommon!(guidType);

    this(Representation guid)
    {
        this.guid = guid;
    }
    this(ubyte realmId, ulong id)
    {
        auto representation = Representation();
        representation.typeMarker = (guidType >>>8);
        representation.realmId = realmId;
        representation.id = id;
        guid = representation;
    }
}

unittest {
    mixin (test!("TypedGuid!(GuidType.Player)"));
    auto test1 = new immutable(TypedGuid!(GuidType.Player))(4, 10);
    assert(test1.id == 10);
    assert(test1.realmId == 4);
    assert(test1.typeMarker == 0);

    auto test2 = new immutable(TypedGuid!(GuidType.Item))(1, 1000045);
    assert(test2.id == 1000045);
    assert(test2.realmId == 1);
    assert(test2.typeMarker == 4);
}

immutable final class TypedGuid(GuidType guidType) if (guidType == GuidType.Instance || guidType == GuidType.Group || guidType == GuidType.Guild)
    : RealmGuid
{
    struct Representation {
        mixin(bitfields!( ushort, "typeMarker", 12, ubyte, "realmId", 8, ulong, "id", 44));
    }

    mixin TypeGuidCommon!guidType;

    this(Representation guid)
    {
        this.guid = guid;
    }
    this(ubyte realmId, ulong id)
    {
        auto representation = Representation();
        representation.typeMarker = guidType;
        representation.realmId = realmId;
        representation.id = id;
        guid = representation;
    }
}

unittest {

    mixin (util.test.test!(TypedGuid));
    void test(GuidType type)()
    {
        auto test = new immutable(TypedGuid!(type))(4, 10);
        assert(test.id == 10);
        assert(test.realmId == 4);
        assert(test.typeMarker == type);
    }

    test!(GuidType.Group)();
    test!(GuidType.Guild)();
    test!(GuidType.Instance)();
}

immutable final class TypedGuid(GuidType guidType) if (guidType == GuidType.DynObject)
    : MapGuid
{
    struct Representation {
        mixin(bitfields!( ubyte, "typeMarker0", 4, ubyte, "unkId", 4, ubyte, "typeMarker1", 4, ulong, "id", 52));
    }
    mixin TypeGuidCommon!guidType;

    this(Representation guid)
    {
        this.guid = guid;
    }
    this(ulong id, ubyte unkId = 1)
    {
        auto representation = Representation();
        representation.typeMarker0 = (guidType & 0xF00) >>> 8;
        representation.unkId = unkId;
        representation.typeMarker1 = guidType & 0x00F;
        representation.id = id;
        guid = representation;
    }
}

unittest {
    mixin (util.test.test!(TypedGuid));
    auto test = new immutable(TypedGuid!(GuidType.DynObject))(10);
    assert(test.id == 10);
    assert(test.typeMarker0 == 0xF);
    assert(test.unkId == 1);
    assert(test.typeMarker1 == 0x0);
}

immutable final class TypedGuid (GuidType guidType) 
    if (guidType == GuidType.GameObject || guidType == GuidType.Transport || guidType == GuidType.Vehicle
        || guidType == GuidType.Creature || guidType == GuidType.Pet)
    : MapGuid, EntryGuid
{
    struct Representation {
        static if (wowVersion >= WowVersion.V4_0_1_13164) {
            mixin(bitfields!( ubyte, "typeMarker0", 4, ubyte, "unkId", 4, ubyte, "typeMarker1", 4, uint, "entry", 20, uint, "id", 32));
        }
        else {
            mixin(bitfields!( ubyte, "typeMarker0", 4, ubyte, "unkId", 4, ubyte, "typeMarker1", 4, uint, "entry", 28, uint, "id", 24));
        }
    }

    mixin TypeGuidCommon!guidType;

    this(Representation guid)
    {
        this.guid = guid;
    }
    this(uint entry, uint id, ubyte unkId = 1)
    {
        auto representation = Representation();
        representation.entry = entry;
        representation.typeMarker0 = (guidType & 0xF00) >>> 8;
        representation.unkId = unkId;
        representation.typeMarker1 = guidType & 0x00F;
        representation.id = id;
        guid = representation;
    }
    @property uint entry()
    {
        return guid.entry;
    }
}

unittest {
    mixin (util.test.test!(TypedGuid));
    void test(GuidType type, ubyte markerVal)()
    {
        mixin (util.test.test!(type.stringof));
        auto test = new immutable(TypedGuid!(type))(2000, 5000);
        assert(test.entry == 2000);
        assert(test.id == 5000);
        assert(test.typeMarker0 == 0xF);
        assert(test.unkId == 1);
        assert(test.typeMarker1 == markerVal);
    }
    test!(GuidType.GameObject, 1)();
    test!(GuidType.Transport, 2)();
    test!(GuidType.Vehicle, 5)();
    test!(GuidType.Creature, 3)();
    test!(GuidType.Pet, 4)();
}

immutable final class TypedGuid(GuidType guidType) if (guidType == GuidType.BattleGround || guidType == GuidType.MOTransport)
    : UniversalGuid
{
    mixin TypeGuidCommon!(guidType);

    struct Representation {
        mixin(bitfields!( ushort, "typeMarker", 12, ulong, "id", 52)); 
    }

    this(Representation guid)
    {
        this.guid = guid;
    }
    this(ulong id)
    {
        auto representation = Representation();
        representation.typeMarker = guidType;
        representation.id = id;
        guid = representation;
    }
}

unittest {
    mixin (util.test.test!(TypedGuid));
    void test(GuidType type)()
    {
        auto test = new immutable(TypedGuid!(type))(10);
        assert(test.id == 10);
        assert(test.typeMarker == type);
    }

    test!(GuidType.BattleGround)();
    test!(GuidType.MOTransport)();
}