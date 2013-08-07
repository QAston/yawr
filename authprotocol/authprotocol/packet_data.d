module authprotocol.packet_data;

import std.typecons;

import util.protocol.packet_stream;
import util.protocol.direction;
import util.protocol.packet_data;
import util.bit;

import wowdefs.wow_versions;

import authprotocol.opcode;
import authprotocol.defines;

enum ProtocolVersion
{
    PRE_BC,
    POST_BC
}

struct PacketInfo(Opcode OPCODE, Direction DIRECTION, ProtocolVersion VER)
{
    enum op = OPCODE;
    enum dir = DIRECTION;
    enum ver = VER;
}

/+
+ Checks that PacketData can be written to stream and reread from it and have same value
+/
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR, VER)),Opcode OP,Direction DIR, ProtocolVersion VER)(DATA_TYPE inputData)
{
    util.protocol.packet_data.testPacketData!((ubyte[] buffer)=>new PacketStream!false(buffer, null),(ubyte[] buffer)=>new PacketStream!true(buffer, null))(inputData);
}

/+
+ Checks that PacketData definition works as expected with given binary input
+ Params:
+    inputBinary - binary data to test
+    expectedResult - data, which should be result of reading the inputBinary
+/
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR, VER)),Opcode OP,Direction DIR, ProtocolVersion VER)(ubyte[] inputBinary, DATA_TYPE expectedResult)
{
    util.protocol.packet_data.testPacketData!((ubyte[] buffer)=>new PacketStream!false(buffer, null),(ubyte[] buffer)=>new PacketStream!true(buffer, null))(inputBinary, expectedResult);
}

/// ditto
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR, VER)),Opcode OP,Direction DIR, ProtocolVersion VER)(string inputBinary, DATA_TYPE expectedResult)
{
    testPacketData(cast(ubyte[])inputBinary, expectedResult);
}

struct PacketData(PACKET) 
    if (PACKET.dir == Direction.c2s && (PACKET.op == Opcode.AUTH_LOGON_CHALLENGE || PACKET.op == Opcode.AUTH_RECONNECT_CHALLENGE))
{
    ubyte unk; // for AUTH_LOGON_CHALLENGE - 6 in PseuWow
    ubyte[4] gamename;
    BuildInfo build;
    ubyte[4] platform;
    ubyte[4] os;
    ubyte[4] country;
    uint timezone_bias;
    uint ip;
    char[] accountName;

    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val(unk);
        p.valBlockSize!(ushort, false)({
            p.valArray(gamename);
            p.val(build);
            p.valArray(platform);
            p.valArray(os);
            p.valArray(country);
            p.val(timezone_bias);
            p.val(ip);
            p.valCount!(ubyte)(accountName);
            p.valArray(accountName);
        });
    }
}

unittest {
    auto t1 = PacketData!(PacketInfo!(Opcode.AUTH_LOGON_CHALLENGE, Direction.c2s, ProtocolVersion.POST_BC))();
    t1.unk = 6;
    auto pi = getPatchInfo(WowVersion.V4_3_4_15595);
    t1.build = BuildInfo(pi.major, pi.minor, pi.bugfix, WowVersion.V4_3_4_15595);
    t1.accountName = cast(char[])"ACCOUNT";
    testPacketData(t1);
}

struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_LOGON_CHALLENGE && PACKET.dir == Direction.s2c)
{
    ubyte unk;
    AuthResult result;
    Nullable!SecurityInfo info;
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val(unk);
        p.val(result);
        // p.val(info);
    }
}

unittest {
    auto t1 = PacketData!(PacketInfo!(Opcode.AUTH_LOGON_CHALLENGE, Direction.s2c, ProtocolVersion.POST_BC))();
    //testPacketData(t1);
}

struct SecurityInfo
{
    ubyte[32] B;
    ubyte[] g;
    ubyte[] N;
    SecurityFlags flags;
    Nullable!uint unkPin;
    Nullable!ulong unkPin2;
    Nullable!ulong unkPin3;
    Nullable!uint unkMatrix;
    Nullable!ulong unkMatrix2;
    Nullable!ubyte unkToken; // 1
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val(B);
        p.valCount(g);
        p.valArray(g);
        p.valCount(N);
        p.valArray(N);
        p.val!(as!ubyte)(flags);
    }
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_RECONNECT_CHALLENGE && PACKET.dir == Direction.s2c)
{
    align(1):
    AuthResult result;
    ubyte[16] reconnectProof;
    ubyte[16] unkBytes;
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        auto bytes = asByteArray(this);
        p.valArray(bytes);
    }
}

unittest {
    testPacketData(PacketData!(PacketInfo!(Opcode.AUTH_RECONNECT_CHALLENGE, Direction.s2c, ProtocolVersion.POST_BC))(AuthResult.WOW_SUCCESS));
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_LOGON_PROOF && PACKET.dir == Direction.c2s)
{
    align(1):
    ubyte A[32];
    ubyte M1[20];
    ubyte crc_hash[20];
    ubyte number_of_keys;
    SecurityFlags securityFlags;                                  // 0x00-0x04
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        auto bytes = asByteArray(this);
        p.valArray(bytes);
    }
}

unittest {
    testPacketData(PacketData!(PacketInfo!(Opcode.AUTH_LOGON_PROOF, Direction.c2s, ProtocolVersion.POST_BC))());
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_LOGON_PROOF && PACKET.dir == Direction.s2c)
{
    align(1):
    AuthResult error; // for WOW_FAIL_UNKNOWN_ACCOUNT followed by ubytes: - 3, 0
    ubyte M2[20];
    static if (PACKET.ver == ProtocolVersion.POST_BC)
        uint  unk1;
    ushort unk2;
    static if (PACKET.ver == ProtocolVersion.POST_BC)
        ushort unk3;

    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        auto bytes = asByteArray(this);
        p.valArray(bytes);
    }
}

unittest {
    testPacketData(PacketData!(PacketInfo!(Opcode.AUTH_LOGON_PROOF, Direction.s2c, ProtocolVersion.POST_BC))());
    testPacketData(PacketData!(PacketInfo!(Opcode.AUTH_LOGON_PROOF, Direction.s2c, ProtocolVersion.PRE_BC))());
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_RECONNECT_PROOF && PACKET.dir == Direction.c2s)
{
    align(1):
    ubyte R1[16];
    ubyte R2[20];
    ubyte R3[20];
    ubyte number_of_keys;
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        auto bytes = asByteArray(this);
        p.valArray(bytes);
    }
}

unittest {
    testPacketData(PacketData!(PacketInfo!(Opcode.AUTH_RECONNECT_PROOF, Direction.c2s, ProtocolVersion.POST_BC))());
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_RECONNECT_PROOF && PACKET.dir == Direction.s2c)
{
    align(1):
    AuthResult result;
    ushort unkZeros;
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        auto bytes = asByteArray(this);
        p.valArray(bytes);
    }
}

unittest {
    testPacketData(PacketData!(PacketInfo!(Opcode.AUTH_RECONNECT_PROOF, Direction.s2c, ProtocolVersion.POST_BC))());
}

struct PacketData(PACKET) if (PACKET.op == Opcode.REALM_LIST && PACKET.dir == Direction.s2c)
{
    uint unk;
    RealmInfo!(PACKET.ver)[] realms;
    ubyte unk1;
    ubyte unk2;
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.valBlockSize!(ushort, false)({
            p.val(unk);
            p.valCount!uint(realms);
            p.valArray(realms);
            p.val(unk1);
            p.val(unk2);
        });
    }
}

unittest {
    //RealmInfo!(ProtocolVersion.POST_BC);
    //auto t1 = PacketData!(PacketInfo!(Opcode.REALM_LIST, Direction.s2c, ProtocolVersion.POST_BC))();
    //t1.realms = [RealmInfo(RealmFlags.""
    //testPacketData()());
    //testPacketData(PacketData!(PacketInfo!(Opcode.REALM_LIST, Direction.s2c, ProtocolVersion.PRE_BC))());
}

struct RealmInfo(ProtocolVersion ver)
{
    RealmFlags flags;
    char[] name;
    char[] address;
    float populationLevel;
    ubyte charsOnRealm;
    ubyte timezone;
    ubyte unk;

    static if(ver == ProtocolVersion.POST_BC)
        BuildInfo build;

    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val(flags);
        p.valCount!uint(name);
        p.valArray(name);
        p.valCount!uint(address);
        p.valArray(address);
        p.val(populationLevel);
        p.val(charsOnRealm);
        p.val(timezone);
        p.val(unk);
        static if(ver == ProtocolVersion.POST_BC)
            p.val(build);
    }
}

align(1)
struct BuildInfo
{
    align(1):
    MajorWowVersion major;
    ubyte minor;
    ubyte bugfix;
    WowVersion build;
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        auto bytes = asByteArray(this);
        p.valArray(bytes);
    }
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.REALM_LIST && PACKET.dir == Direction.c2s)
{
    align(1):
    uint unk;
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        auto bytes = asByteArray(this);
        p.valArray(bytes);
    }
}

unittest {
    testPacketData(PacketData!(PacketInfo!(Opcode.REALM_LIST, Direction.c2s, ProtocolVersion.POST_BC))());
}