/+
 + Defines interface which packetparser_wowversionXXX.dll needs to provide to packetparser_app
 + Hides WowVersion dependant stuff inside a plugin dll
 +/
module packet;

extern void[] read(Packet!true packet, Opcode opcode);
extern void write(Packet!false packet, Opcode opcode, void[] packetData);
extern void print();
