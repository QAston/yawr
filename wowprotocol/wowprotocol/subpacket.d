module wowprotocol.subpacket;

import wowprotocol.opcode;

/+
 + Representation of subpacket data inside a packet
 +/
struct Subpacket {
    Opcode opcode;
    void[] data;
}