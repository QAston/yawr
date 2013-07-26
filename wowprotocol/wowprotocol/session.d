module wowprotocol.session;

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
        void[] decompress(bool stream, void[] compressedData, size_t uncompressedSize)
        {
            if (!stream)
                return uncompress(compressedData, uncompressedSize).dup;
            return uncompressStream.uncompress(compressedData, uncompressedSize).dup;
        }

        void[] compress(bool stream, void[] uncompressedData)
        {
            if (!stream)
                return .compress(uncompressedData).dup;
            return (compressStream.compress(uncompressedData) ~ compressStream.flush(Z_SYNC_FLUSH)).dup;
        }
    }
    else
    {
        void[] decompress(bool stream, void[] compressedData, size_t uncompressedSize)
        {
            return .uncompress(compressedData, uncompressedSize).dup;
        }

        void[] compress(bool stream, void[] uncompressedData)
        {
            return .compress(uncompressedData).dup;
        }
    }
}