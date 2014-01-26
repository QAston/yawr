module wowprotocol.packet_data_.session;

import wowprotocol.opcode;
import wowdefs.wow_version;
import util.protocol.packet_stream;
import util.protocol.direction;
import wowprotocol.packet_data;

struct PacketData(PACKET) if(PACKET.op == Opcode.SMSG_AUTH_CHALLENGE && wowVersion == WowVersion.V4_3_4_15595) {
    uint[8] key;
    uint serverSeed;
    bool unk;

    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val(key[0]);
        p.val(key[1]);
        p.val(key[2]);
        p.val(key[3]);
        p.val(key[4]);
        p.val(key[5]);
        p.val(key[6]);
        p.val(key[7]);
        p.val(serverSeed);
        p.val(unk);
    }

    unittest {
        testPacketData(Packet!(Opcode.SMSG_AUTH_CHALLENGE, Direction.s2c)());
    }
}

struct PacketData(PACKET) if(PACKET.op == Opcode.SMSG_AUTH_CHALLENGE && wowVersion == WowVersion.V3_3_5a_12340) {
    uint[8] newSeeds;
    uint serverSeed;
    uint shuffleCount;

    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val(shuffleCount);
        p.val(serverSeed);
        p.valArray(newSeeds);
    }

    unittest {
        testPacketData(Packet!(Opcode.SMSG_AUTH_CHALLENGE, Direction.s2c)());
    }
}

struct PacketData(PACKET) if(PACKET.op == Opcode.CMSG_AUTH_SESSION  && wowVersion == WowVersion.V3_3_5a_12340) {
    byte[20] sha;
    uint clientBuild;
    char[] accountName;
    uint clientSeed;
    uint unk2, unk3, unk5, unk6, unk7;
    ulong unk4;
    ClientAddonsList!(false) clientAddonsList;
    
    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.val(clientBuild);
        p.val(unk2);
        p.val!(asCString)(accountName);
        p.val(unk3);
        p.val(clientSeed);
        p.val(unk5);
        p.val(unk6);
        p.val(unk7);
        p.val(unk4);
        p.valArray(sha);
        p.val(clientAddonsList);
    }

    unittest {
        testPacketData(Packet!(Opcode.SMSG_AUTH_CHALLENGE, Direction.c2s)());
    }
}

struct PacketData(PACKET) if(PACKET.op == Opcode.CMSG_AUTH_SESSION  && wowVersion == WowVersion.V4_3_4_15595) {
    byte[20] sha;
    WowVersion build;
    char[] accountName;
    uint clientSeed;
    ClientAddonsList!(true) clientAddonsList;

    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.skip!uint;
        p.skip!uint;
        p.skip!byte;
        p.val(sha[10]);
        p.val(sha[18]);
        p.val(sha[12]);
        p.val(sha[5]);
        p.skip!ulong;
        p.val(sha[15]);
        p.val(sha[9]);
        p.val(sha[19]);
        p.val(sha[4]);
        p.val(sha[7]);
        p.val(sha[16]);
        p.val(sha[3]);
        p.val!(as!ushort)(build);
        p.val(sha[8]);
        p.skip!uint;
        p.skip!byte;
        p.val(sha[17]);
        p.val(sha[6]);
        p.val(sha[0]);
        p.val(sha[1]);
        p.val(sha[11]);
        p.val!(as!uint)(clientSeed);
        p.val(sha[2]);
        p.skip!uint;
        p.val(sha[14]);
        p.val(sha[13]);

        p.val(clientAddonsList);

        p.skip!(byte, asBits!(1));

        p.valCount!(uint, asBits!(12))(accountName);

        p.valArray(accountName);
    }

    unittest {
        import std.conv;
        auto t1 = Packet!(Opcode.CMSG_AUTH_SESSION, Direction.c2s)();
        t1.accountName = "asd".to!(char[]);
        t1.clientAddonsList.addons = [Addon("addon1", true, 0, 0), Addon("addon2", false, 0, 0)];
        testPacketData(t1);
    }
}

struct Addon {
    string name;
    bool enabled;
    int crc;
    uint unknown;
}

alias uint Time;
struct ClientAddonsList(bool valDeflatedSize) {
    Addon[] addons;

    Time time;

    void stream(PACKET_STREAM)(PACKET_STREAM p)
    {
        p.deflateBlock!(false, valDeflatedSize)((){
            p.valCount!(uint)(addons);

            foreach(ref addon; addons)
            {
                p.val!(asCString)(addon.name);
                p.val(addon.enabled);
                p.val(addon.crc);
                p.val(addon.unknown);
            }
            p.val(time);
        });
    }
}

static if (wowVersion >= WowVersion.V4_3_4_15595)
{
    struct PacketData(PACKET) if(PACKET.op == (Opcode.SMSG_MOVE_SET_RUN_SPEED))
    {
        uint unk;
        float speed;
        ulong guid;
        void stream(PACKET_STREAM)(PACKET_STREAM p)
        {
            p.valPackMarkByteSeq(guid, 6, 1, 5, 2, 7, 0, 3, 4);
            p.valPackByteSeq(guid, 5,3,1,4);
            p.val(unk);
            p.val(speed);
            p.valPackByteSeq(guid, 6,0,7,2);
        }
    }

    unittest {
        testPacketData(x"5E 05 E2 10 00 00 00 00 00 E0 40 D9 07 57", Packet!(Opcode.SMSG_MOVE_SET_RUN_SPEED, Direction.s2c)(16, 7, 432345564300370904));
        testPacketData(Packet!(Opcode.SMSG_MOVE_SET_RUN_SPEED, Direction.s2c)(16, 7, 432345564300370904));
    }
}