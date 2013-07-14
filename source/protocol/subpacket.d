module protocol.subpacket;

import protocol.opcode;

/+
 + Representation of subpacket data inside a packet
 +/
struct Subpacket {
    Opcode opcode;
    void[] data;
}