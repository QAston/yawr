module packet;

import std.datetime;

import vibe.stream.memory;

class Packet 
{
	this()
	{
		// Constructor code
	}
}

enum Direction { c2s = 0, s2c = 1 };
enum Opcode { a };

class PacketDump : Packet {
	Direction direction;
	SysTime dateTime;
	MemoryStream data;
	Opcode opcode;

	this(ubyte[] data, uint opcode, Direction direction, SysTime dateTime)
	{
		this.data = new MemoryStream(data);
		this.opcode = cast(Opcode)opcode;
		this.direction = direction;
		this.dateTime = dateTime;
	}
}