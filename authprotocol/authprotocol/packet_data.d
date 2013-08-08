/+
 + This module defines packet data structures for auth client-server communication protocol
 + These structures are converted to/from stream using stream function provided by PacketData structures
 +/
module authprotocol.packet_data;

import util.protocol.packet_stream;
import util.protocol.direction;
import util.protocol.packet_data;
import util.bit;
import util.typecons;

import wowdefs.wow_versions;

import authprotocol.opcode;
import authprotocol.defines;

enum ProtocolVersion
{
    PRE_BC,
    POST_BC
}

/// Compile time struct identifying a packet data
struct PacketInfo(Opcode OPCODE, Direction DIRECTION, ProtocolVersion VER)
{
    enum op = OPCODE;
    enum dir = DIRECTION;
    enum ver = VER;
}

/// Shorthand for accessing PacketData!(PacketInfo! type
template Packet(Opcode OPCODE, Direction DIRECTION, ProtocolVersion VER)
{
    alias PacketData!(PacketInfo!(OPCODE, DIRECTION, VER)) Packet;
}

/+
+ Checks that PacketData can be written to stream and reread from it and have same value
+ Watch out for NAN values in PacketData (default float)- tests for those will fail
+/
void testPacketData(DATA_TYPE : PacketData!(PacketInfo!(OP, DIR, VER)),Opcode OP,Direction DIR, ProtocolVersion VER)(DATA_TYPE inputData)
{
    util.protocol.packet_data.testPacketData!((ubyte[] buffer)=>new PacketStream!false(buffer, null),(ubyte[] buffer)=>new PacketStream!true(buffer, null))(inputData);
}

/+
+ Checks that PacketData definition works as expected with given binary input
+ Watch out for NAN values in PacketData (default float) - tests for those will fail
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
    auto t1 = Packet!(Opcode.AUTH_LOGON_CHALLENGE, Direction.c2s, ProtocolVersion.POST_BC)();
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
    Opt!SecurityInfo info;
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val(unk);
        p.val(result);
        if (result == AuthResult.WOW_SUCCESS)
            p.val(info);
    }

    struct SecurityInfo
    {
        ubyte[32] B;
        ubyte[] g;
        ubyte[] N;
        Flags!SecurityFlags flags;
        Opt!Pin pin;
        Opt!Matrix matrix;
        Opt!Token token;
        void stream(PACKET_STREAM)(PACKET_STREAM p)
        {
            p.valArray(B);
            p.valCount!ubyte(g);
            p.valArray(g);
            p.valCount!ubyte(N);
            p.valArray(N);
            p.val!(as!ubyte)(flags);
            if (flags & SecurityFlags.PIN_INPUT)
                p.val(pin);
            if (flags & SecurityFlags.MATRIX_INPUT)
                p.val(matrix);
            if (flags & SecurityFlags.TOKEN_INPUT)
                p.val(token);
        }

        align(1)
            struct Pin
            {
                align(1):
                uint unk1;
                ulong unk2;
                ulong unk3;
                void stream(PACKET_STREAM)(PACKET_STREAM p)
                {
                    auto bytes = asByteArray(this);
                    p.valArray(bytes);
                }
            }

        align(1)
            struct Matrix
            {
                align(1):
                uint unk1;
                ulong unk2;
                void stream(PACKET_STREAM)(PACKET_STREAM p)
                {
                    auto bytes = asByteArray(this);
                    p.valArray(bytes);
                }
            }

        align(1)
            struct Token
            {
                align(1):
                ubyte unk;
                void stream(PACKET_STREAM)(PACKET_STREAM p)
                {
                    auto bytes = asByteArray(this);
                    p.valArray(bytes);
                }
            }
    }
}

unittest {
    auto t1 = Packet!(Opcode.AUTH_LOGON_CHALLENGE, Direction.s2c, ProtocolVersion.POST_BC)();
    t1.result = AuthResult.WOW_FAIL_BANNED;
    testPacketData(t1);
    auto t2 = Packet!(Opcode.AUTH_LOGON_CHALLENGE, Direction.s2c, ProtocolVersion.POST_BC)();
    t2.result = AuthResult.WOW_SUCCESS;
    auto secInf = typeof(t2).SecurityInfo();
    secInf.flags = SecurityFlags.TOKEN_INPUT;
    secInf.token = typeof(secInf).Token(cast(ubyte)1);
    secInf.g = emptyArray!ubyte;
    secInf.N = emptyArray!ubyte;

    t2.info = secInf;
    testPacketData(t2);
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_RECONNECT_CHALLENGE && PACKET.dir == Direction.s2c)
{
    align(1):
    AuthResult result;
    ubyte[16] reconnectProof;
    ubyte[16] unkBytes;

    mixin streamAsRawBytes;
}

unittest {
    testPacketData(Packet!(Opcode.AUTH_RECONNECT_CHALLENGE, Direction.s2c, ProtocolVersion.POST_BC)(AuthResult.WOW_SUCCESS));
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_LOGON_PROOF && PACKET.dir == Direction.c2s)
{
    align(1):
    ubyte A[32];
    ubyte M1[20];
    ubyte crc_hash[20];
    ubyte number_of_keys;
    SecurityFlags securityFlags;
    mixin streamAsRawBytes;
}

unittest {
    testPacketData(Packet!(Opcode.AUTH_LOGON_PROOF, Direction.c2s, ProtocolVersion.POST_BC)());
}


struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_LOGON_PROOF && PACKET.dir == Direction.s2c)
{
    AuthResult error;
    Opt!Proof proof;
    Opt!UnknownAccError unkAccError;

    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val!(as!ubyte)(error);
        with (AuthResult) switch (error)
        {
            case WOW_SUCCESS:
                p.val(proof);
                break;
            case WOW_FAIL_UNKNOWN_ACCOUNT:
                p.val(unkAccError);
                break;
            default:
                // possibly there should be similar structs for other errors
                break;
        }
    }

    align(1)
    struct Proof
    {
        align(1):
        ubyte M2[20];
        static if (PACKET.ver == ProtocolVersion.POST_BC)
            uint  unk1;
        ushort unk2;
        static if (PACKET.ver == ProtocolVersion.POST_BC)
            ushort unk3;
        mixin streamAsRawBytes;
    }

    align(1)
    struct UnknownAccError
    {
        align(1):
        ubyte unk1;
        ubyte unk2;
        mixin streamAsRawBytes;
    }
}

unittest {
    {
        auto t1 = Packet!(Opcode.AUTH_LOGON_PROOF, Direction.s2c, ProtocolVersion.POST_BC)();
        auto proof = typeof(t1).Proof();
        t1.proof = proof;
        testPacketData(t1);
    }

    {
        auto t2 = Packet!(Opcode.AUTH_LOGON_PROOF, Direction.s2c, ProtocolVersion.PRE_BC)();
        auto proof = typeof(t2).Proof();
        t2.proof = proof;
        testPacketData(t2);
    }
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_RECONNECT_PROOF && PACKET.dir == Direction.c2s)
{
    align(1):
    ubyte R1[16];
    ubyte R2[20];
    ubyte R3[20];
    ubyte number_of_keys;
    mixin streamAsRawBytes;
}

unittest {
    testPacketData(Packet!(Opcode.AUTH_RECONNECT_PROOF, Direction.c2s, ProtocolVersion.POST_BC)());
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.AUTH_RECONNECT_PROOF && PACKET.dir == Direction.s2c)
{
    align(1):
    AuthResult result;
    ushort unkZeros;
    mixin streamAsRawBytes;
}

unittest {
    testPacketData(Packet!(Opcode.AUTH_RECONNECT_PROOF, Direction.s2c, ProtocolVersion.POST_BC)());
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
    auto realmInfo = RealmInfo!(ProtocolVersion.POST_BC)();
    realmInfo.name = cast(char[])"cool_realm";
    realmInfo.address = cast(char[])"127.0.0.1";
    auto pi = getPatchInfo(WowVersion.V4_3_4_15595);
    realmInfo.build = BuildInfo(pi.major, pi.minor, pi.bugfix, WowVersion.V4_3_4_15595);
    auto t1 = Packet!(Opcode.REALM_LIST, Direction.s2c, ProtocolVersion.POST_BC)();
    t1.realms = [realmInfo];
    testPacketData(t1);
}

struct RealmInfo(ProtocolVersion ver)
{
    RealmFlags flags;
    char[] name;
    char[] address;
    float populationLevel = 0; // avoid NAN
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
    mixin streamAsRawBytes;
}

align(1)
struct PacketData(PACKET) if (PACKET.op == Opcode.REALM_LIST && PACKET.dir == Direction.c2s)
{
    align(1):
    uint unk;
    mixin streamAsRawBytes;
}

unittest {
    testPacketData(Packet!(Opcode.REALM_LIST, Direction.c2s, ProtocolVersion.POST_BC)());
}