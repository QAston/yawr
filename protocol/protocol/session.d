module protocol.session;

import util.zlib;

import wowdefs.wow_version;

class Session {
    static if (wowVersion >= WowVersion.V4_3_0_15005)
    {
        UnCompress uncompressStream = new UnCompress();
        Compress compressStream = new Compress();
    }
}