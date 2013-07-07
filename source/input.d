/+
 + Provides packet input ranges
 +/
module input;

import std.range;
import std.datetime;
import std.stdio;
import std.file;

import vibe.core.stream;
import vibe.stream.operations;

import packet;
import stream_utils;
import util;


/+
 + Basic type for packet input ranges
 +/
interface PacketInput
{
	@property Packet front();
	
	void popFront();
	
	@property bool empty();

	@property int getBuild();
}

/+
 + .pkt packet format handler
 + Provides PacketInput range
 +/
class PktPacketInput : PacketInput
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
	}

	private {
		InputStream stream;
		PktVersion pktVersion;
		uint startTickCount = 0;
		SysTime startTime;
		Packet _front;
	}


	override @property Packet front()
	{
		return _front;
	}

	override @property bool empty()
	{
		return stream.empty();
	}

	override @property int getBuild()
	{
		return 0;
	}

	private void readHeader()
	{
		auto headerStart = stream.peekAllUTF8(3u);             // PKT
		if (headerStart == "PKT")
		{
			stream.readAll(3u);
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
				break;
			}
			case PktVersion.V2_1:
			{
				stream.sread!ushort; // client build
				stream.readAll(40); // session key
				break;
			}
			case PktVersion.V2_2:
			{
				stream.sread!ubyte;                         // sniffer id
				stream.sread!ushort;                       // client build
				stream.readAll(4);                       // client locale
				stream.readAll(20);                      // packet key
				stream.readAll(64);                      // realm name
				break;
			}
			case PktVersion.V3_0:
			{
				auto snifferId = stream.sread!ubyte;         // sniffer id
				stream.sread!uint;             // client build
				stream.readAll(4);                       // client locale
				stream.readAll(40);                      // session key
				additionalLength = stream.sread!uint;
				if (snifferId == 10)                        // xyla
				{
					additionalLength -= 8;

					startTime = unixTimeToSysTime(stream.sread!uint);   // start time
					startTickCount = stream.sread!uint; // start tick count
				}
				stream.readAll(additionalLength);
				break;
			}
			case PktVersion.V3_1:
			{
				stream.sread!ubyte;                        // sniffer id
				stream.sread!uint;             // client build
				stream.readAll(4);                       // client locale
				stream.readAll(40);                      // session key
				startTime = unixTimeToSysTime(stream.sread!uint); // start time
				startTickCount = stream.sread!uint;     // start tick count
				additionalLength = stream.sread!int;
				stream.readAll(additionalLength);
				break;
			}
		}
	}
	
	override void popFront()
	{
		int opcode;
		int length;
		SysTime time;
		packet.Direction direction;
		ubyte[] data;
		
		uint cIndex = 0;
		
		{
			final switch (pktVersion)
			{
				case PktVersion.V1:
				{
					opcode = stream.sread!ushort;
					length = stream.sread!int;
					direction = cast(packet.Direction)stream.sread!byte;
					time = unixTimeToSysTime(cast(core.stdc.time.time_t)stream.sread!ulong);
					data = stream.readAll(length);
					break;
				}
				case PktVersion.V2_1:
				case PktVersion.V2_2:
				{
					direction = (stream.sread!ubyte == 0xff) ? packet.Direction.s2c : packet.Direction.c2s;
					time = unixTimeToSysTime(stream.sread!int);
					stream.sread!int; // tick count
					length = stream.sread!int;
					
					if (direction == packet.Direction.s2c)
					{
						opcode = stream.sread!ushort;
						data = stream.readAll(length - 2);
					}
					else
					{
						opcode = stream.sread!int;
						data = stream.readAll(length - 4);
					}
					
					break;
				}
				case PktVersion.V3_0:
				case PktVersion.V3_1:
				{
					direction = (stream.sread!uint == 0x47534d53) ? packet.Direction.s2c : packet.Direction.c2s;
					
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
					stream.readAll(additionalSize);
					opcode = stream.sread!int;
					data = stream.readAll(length - 4);
					break;
				}
			}
		}

		// FIXME
		// ignore opcodes that were not "decrypted" (usually because of
		// a missing session key) (only applicable to 335 or earlier)
		//if (opcode >= 1312 && ClientVersion.Build <= ClientVersionBuild.V3_3_5a_12340 && ClientVersion.Build > ClientVersionBuild.Zero)
			//return null;
		
		_front = new PacketDump(data, opcode, direction, time);
	}
}

/+
 + .bin packet format handler
 + Provides PacketInput range
 +/
class BinaryPacketInput : PacketInput
{
	private InputStream stream;

	private Packet _front;
	
	this(InputStream stream)
	{
		this.stream = stream;
		this._front = null;
	}

	override @property Packet front()
	{
		return _front;
	}
	
	override void popFront()
	{
		auto opcode = stream.sread!uint;
		auto length = stream.sread!uint;
		auto time = unixTimeToSysTime(stream.sread!int);
		auto direction = cast(packet.Direction)stream.sread!char();
		auto data = stream.readAll(length);
		
		_front = new PacketDump(data, opcode, direction, time);
	}
	
	override @property bool empty()
	{
		return stream.empty();
	}
	
	override @property int getBuild()
	{
		return 0;
	}
}


