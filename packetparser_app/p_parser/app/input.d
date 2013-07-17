/+
 + Provides packet input ranges
 +/
module p_parser.app.input;

import std.range;
import std.datetime;
import std.stdio;
import std.file;

import vibe.core.stream;

import util.stream;
import util.time;

import p_parser.dump;

import util.wow_versions;

/+
 + Returns a PacketInput which handles reading from a file with given filename
 +/
PacketInput getPacketInput(string fileName)
out (result) {
    assert (result !is null);
}
body {
    import std.string;
    import vibe.core.file;
    FileStream stream = openFile(fileName, FileMode.read);
    if (fileName.endsWith(".pkt"))
    {
        return new PktPacketInput(stream);
    }
    else if (fileName.endsWith(".bin"))
    {
        return new BinaryPacketInput(stream);
    }
    else
    {
        throw new Exception("File: " ~ fileName ~ " has unknown file format");
    }
}


/+
 + Basic type for packet input ranges
 +/
class PacketInput : InputRange!PacketDump
{
    /+
     + Input range primitives
     +/
    PacketDump moveFront()
    {
        PacketDump ret = front();
        if (!empty)
        {
            popFront();
        }
        return ret;
    }

    /// Ditto
    int opApply(int delegate(PacketDump) dg)
    {
        int result = 0;
        while (!empty())
        {
            result = dg(moveFront());
            if (result)
                break;
        }
        return result;
    }

    /// Ditto
    int opApply(int delegate(uint, PacketDump) dg)
    {
        uint i = 0;
        int result = 0;
        while (!empty())
        {
            result = dg(i, moveFront());
            i++;
            if (result)
                break;
        }
        return result;
    }

    /// Ditto
    abstract @property PacketDump front();
    /// Ditto
    abstract @property bool empty();
    /// Ditto
    abstract void popFront();

    /+
     + returns WowVersion of packets stored in range
     + 
     + based on packet's date
     +/
    @property WowVersion getBuild()
    out (result) {
        assert(result != WowVersion.Undefined);
    }
    body {
        return getWowVersion(Date(front.dateTime.year, front.dateTime.month, front.dateTime.day));
    }
}

/+
 + .pkt packet format handler
 + Provides PacketInput range
 +/
final class PktPacketInput : PacketInput
{
	enum PktVersion : ushort
	{
		V1 = 0,
		V2_1 = 0x201,
		V2_2 = 0x202,
		V3_0 = 0x300,
		V3_1 = 0x301,
	}
	
	this(InputStream stream)
	{
		this.stream = stream;
		this._front = null;
		readHeader();
        if (!empty())
            popFront();
	}

	private {
		InputStream stream;
		PktVersion pktVersion;
		uint startTickCount = 0;
		SysTime startTime;
        PacketDump* _front;
        ubyte[] additionalData;
        WowVersion clientBuild;
	}


    override @property PacketDump front()
	{
        assert(_front !is null);
		return *_front;
	}

	override @property bool empty()
	{
		return stream.empty();
	}

	override @property WowVersion getBuild()
	{
        if (pktVersion == PktVersion.V1)
            return super.getBuild();
		return clientBuild;
	}

	private void readHeader()
	{
        ubyte[3] marker;
        stream.read(marker[]);             // PKT
        if (marker == "PKT")
		{
			pktVersion = cast(PktVersion)stream.sread!ushort();      // sniff version
		}
		else
		{
			pktVersion = PktVersion.V1; // pkt v1 is headerless
		}
		
		int additionalLength;
		
		final switch (pktVersion)
		{
			case PktVersion.V1:
			{
                additionalData = marker[];
				break;
			}
			case PktVersion.V2_1:
			{
				clientBuild = cast(WowVersion)stream.sread!ushort; // client build
				stream.sreadBytes(40); // session key
				break;
			}
			case PktVersion.V2_2:
			{
				stream.sread!ubyte;                         // sniffer id
				clientBuild = cast(WowVersion)stream.sread!ushort;                       // client build
				stream.sreadBytes(4);                       // client locale
				stream.sreadBytes(20);                      // packet key
				stream.sreadBytes(64);                      // realm name
				break;
			}
			case PktVersion.V3_0:
			{
				auto snifferId = stream.sread!ubyte;         // sniffer id
				clientBuild = cast(WowVersion)stream.sread!uint;             // client build
				stream.sreadBytes(4);                       // client locale
				stream.sreadBytes(40);                      // session key
				additionalLength = stream.sread!uint;
				if (snifferId == 10)                        // xyla
				{
					additionalLength -= 8;

					startTime = unixTimeToSysTime(stream.sread!uint);   // start time
					startTickCount = stream.sread!uint; // start tick count
				}
				stream.sreadBytes(additionalLength);
				break;
			}
			case PktVersion.V3_1:
			{
				stream.sread!ubyte;                        // sniffer id
				clientBuild = cast(WowVersion)stream.sread!uint;             // client build
				stream.sreadBytes(4);                       // client locale
				stream.sreadBytes(40);                      // session key
				startTime = unixTimeToSysTime(stream.sread!uint); // start time
				startTickCount = stream.sread!uint;     // start tick count
				additionalLength = stream.sread!int;
				stream.sreadBytes(additionalLength);
				break;
			}
		}
	}
	
	override void popFront()
	{
		int opcode;
		int length;
		SysTime time;
		p_parser.dump.Direction direction;
		ubyte[] data;
		
		uint cIndex = 0;
		
		{
			final switch (pktVersion)
			{
				case PktVersion.V1:
				{
					opcode = stream.sread!ushort;
					length = stream.sread!int;
					direction = cast(p_parser.dump.Direction)stream.sread!byte;
					time = unixTimeToSysTime(cast(core.stdc.time.time_t)stream.sread!ulong);
                    if (additionalData != null)
                    {
                        data = additionalData ~ stream.sreadBytes(length);
                        additionalData = null;
                    }
                    else
                        data = stream.sreadBytes(length);
					break;
				}
				case PktVersion.V2_1:
				case PktVersion.V2_2:
				{
					direction = (stream.sread!ubyte == 0xff) ? p_parser.dump.Direction.s2c : p_parser.dump.Direction.c2s;
					time = unixTimeToSysTime(stream.sread!int);
					stream.sread!int; // tick count
					length = stream.sread!int;
					
					if (direction == p_parser.dump.Direction.s2c)
					{
						opcode = stream.sread!ushort;
						data = stream.sreadBytes(length - 2);
					}
					else
					{
						opcode = stream.sread!int;
						data = stream.sreadBytes(length - 4);
					}
					
					break;
				}
				case PktVersion.V3_0:
				case PktVersion.V3_1:
				{
					direction = (stream.sread!uint == 0x47534d53) ? p_parser.dump.Direction.s2c : p_parser.dump.Direction.c2s;
					
					if (pktVersion == PktVersion.V3_0)
					{
						time = unixTimeToSysTime(stream.sread!int);
						auto tickCount = stream.sread!uint;
						if (startTickCount != 0)
							time = startTime + core.time.dur!"msecs"(tickCount - startTickCount);
					}
					else
					{
						cIndex = stream.sread!uint; // session id, connection index
						auto tickCount = stream.sread!uint;
						time = startTime + core.time.dur!"msecs"(tickCount - startTickCount);
					}
					
					int additionalSize = stream.sread!int;
					length = stream.sread!int;
                    stream.sreadBytes(additionalSize);
					opcode = stream.sread!int;
                    data = stream.sreadBytes(cast(size_t)(length - 4));
					break;
				}
			}
		}
		
		_front = new PacketDump(data, opcode, direction, time);
	}
}

/+
 + .bin packet format handler
 + Provides PacketInput range
 +/
final class BinaryPacketInput : PacketInput
{
	private InputStream stream;

    private PacketDump* _front;
	
	this(InputStream stream)
	{
		this.stream = stream;
		this._front = null;
        if (!empty())
            popFront();
	}

    override @property PacketDump front()
	{
        assert(_front !is null);
		return *_front;
	}
	
	override void popFront()
	{
		auto opcode = stream.sread!uint;
		auto length = stream.sread!uint;
		auto time = unixTimeToSysTime(stream.sread!int);
		auto direction = cast(p_parser.dump.Direction)stream.sread!char();
		auto data = stream.sreadBytes(length);
		
		_front = new PacketDump(data, opcode, direction, time);
	}
	
	override @property bool empty()
	{
		return stream.empty();
	}
}


