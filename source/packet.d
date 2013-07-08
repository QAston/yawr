module packet;

import std.datetime;

import protocol.packet;

enum Direction : uint { c2s = 0, s2c = 1,};

class PacketDump : Packet {
	Direction direction;
	SysTime dateTime;

	this(ubyte[] data, uint opcode, Direction direction, SysTime dateTime)
	{
        super(data, opcode);
		this.direction = direction;
		this.dateTime = dateTime;
      
	}
}