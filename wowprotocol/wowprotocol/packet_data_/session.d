module wowprotocol.packet_data_.session;

import wowprotocol.opcode;
import wowdefs.wow_version;
import util.protocol.packet_stream;
import wowprotocol.packet_data;

struct PacketData(PACKET) if(PACKET.op == Opcode.SMSG_AUTH_CHALLENGE) {
    uint[8] key;
    uint serverSeed;
    bool unk;

    void stream(bool INPUT)(PacketStream!INPUT p)
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

    //@Test()
    void test()
    {
        foreach (i, ref k; key)
        {
            k = i;
        }
        serverSeed = 1234;
        unk = 1;
    }
}

struct PacketData(PACKET) if(PACKET.op == Opcode.CMSG_AUTH_SESSION) {
    byte[20] sha;
    WowVersion build;
    char[] accountName;
    uint clientSeed;
    ClientAddonsList!(true) clientAddonsList;

    void stream(bool INPUT)(PacketStream!INPUT p)
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

    void stream(bool INPUT)(PacketStream!INPUT p)
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

struct PacketData(PACKET) if(PACKET.op == (Opcode.SMSG_MOVE_SET_RUN_SPEED))
{
    uint unk;
    float speed;
    ulong guid;
    void stream(bool INPUT)(PacketStream!INPUT p)
    {
        p.valPackMarkByteSeq(guid, 6, 1, 5, 2, 7, 0, 3, 4);
        p.valPackByteSeq(guid, 5,3,1,4);
        p.val(unk);
        p.val(speed);
        p.valPackByteSeq(guid, 6,0,7,2);
    }
}

unittest {
    auto data = PacketData!(PacketInfo!(Opcode.SMSG_MOVE_SET_RUN_SPEED))();
    //auto d = PacketData!(uint)();
}