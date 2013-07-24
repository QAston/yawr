module protocol.session;

import util.zlib;

import wowdefs.wow_version;

class Session {
    static if (wowVersion >= WowVersion.V4_3_0_15005)
    {
        UnCompress uncompressStream;
        Compress compressStream;

        this()
        {
            uncompressStream = new UnCompress();
            compressStream = new Compress();
        }
    }
}