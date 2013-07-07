module protocol.opcode;

import protocol.version_;
import std.conv;

mixin ("public import protocol.opcode_." ~ protocolVersion.to!string() ~ ";");