module protocol.handler_.session;

import protocol.opcode;
import wowdefs.wow_version;
import protocol.packet;

@Handler!(Opcode.SMSG_AUTH_CHALLENGE)
struct SmsgAuthChallenge {
    uint[8] key;
    uint serverSeed;
    bool unk;

    void handle(bool INPUT)(Packet!INPUT p)
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

alias ushort ClientBuild;


@Handler!(Opcode.CMSG_AUTH_SESSION)
struct AuthSession {
    byte[20] sha;
    ClientBuild build;
    string accountName;
    uint clientSeed;
    //ClientAddonsList!(true) clientAddonsList;

    void handle(bool INPUT)(Packet!INPUT p)
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
        p.val!(as!ushort)(clientSeed);
        p.val(sha[2]);
        p.skip!uint;
        p.val(sha[14]);
        p.val(sha[13]);

       // clientAddonsList.val;

        p.skip!byte;

        //accountName.valCount(asBits(12));
        //accountName.val;
    }
}



struct Addon {
    // cstring
    string name;
    bool enabled;
    int crc;
    // unknown field
    //uint unknown;
}
/*
alias uint Time;
struct ClientAddonsList(bool valDeflatedSize) {
    Addon[] addons;

    Time time;

    void handle()
    {
        // options: deflate stream, write deflated size
        deflatedBlock!(true, valDeflatedSize)((){
            static if (wowVersion >= V3_0_8_9464)
            {
                addons.valCount;

                addons.valArray((Addon a) {
                    a.name.val(asCstring);
                    a.enabled.val;
                    a.crc.val;
                    skip!int;
                }, asRemainingData());

                time.val;
            }
            else
            {
                addons.valArray((Addon a) {
                    a.name.val(asCstring);
                    a.enabled.val;
                    a.crc.val;
                    skip!int;
                }, asRemainingData());
            }
        });
    }
}*/