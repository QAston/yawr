/++
 + This module handles access to protocol.handler_.* packet handlers
 +/
module protocol.handler;

public import protocol.handler_.session;
import protocol.packet;
import protocol.opcode;
import std.traits;
import std.typetuple;
import std.string;
import std.conv;

struct HandlerEntry {
    TypeInfo typeInfo;
    void function(Packet!true) inputHandler;
    void function(Packet!false) outputHandler;
}

template isHandlerStructPred(alias T)
{
    enum isHandlerStructPred = T.stringof.startsWith("Handler!");//is (typeof(T) == Handler);
}

template isHandler(alias name)
{
    enum hasHandleFunction = __traits(compiles, name.init.handle!true(cast(Packet!true)null)) && __traits(compiles, name.init.handle!false(cast(Packet!false)null));

    static if (std.typetuple.Filter!(isHandlerStructPred, __traits(getAttributes,name)).length != 0) {
        static assert(hasHandleFunction, "Type " ~ fullyQualifiedName!name ~ " has Handler attribute (is marked as packet handler), but it doesn't have void handle(bool INPUT) function!");
        enum isHandler = true;
    }
    else
        enum isHandler = false;
}

template HandlerWithOpcodes(alias packetHandlerSymbol, alias opcodesTuple)
{
    alias packetHandlerSymbol handler;
    alias TypeTuple!(opcodesTuple) opcodes;
}

template getHandlerWithOpcodes(alias packetHandlerSymbol)
{
    template getHandlerOpcode(alias handlerSymbol)
    {
        alias getHandlerOpcode = TypeTuple!(handlerSymbol.opcode);
    }
    alias getHandlerWithOpcodes = HandlerWithOpcodes!(packetHandlerSymbol, std.typetuple.staticMap!(getHandlerOpcode, std.typetuple.Filter!(isHandlerStructPred, __traits(getAttributes,packetHandlerSymbol))));
}

private static HandlerEntry[Opcode] handlers;

static this()
{
    foreach(handlerOpcode; staticMap!(getHandlerWithOpcodes, protocol.attribute_utils.ModuleMembersMatching!(protocol.handler_.session, isHandler)))
    {
        foreach(opc; handlerOpcode.opcodes)
        {
            assert (opc !in handlers, "Opcode " ~ opc.opcodeToString ~ " has more than one handler registered for it");
            handlers[opc] = HandlerEntry(typeid(handlerOpcode.handler), &handlerOpcode.handler.handle!true, &handlerOpcode.handler.handle!false);
        }
    }
}
/+
 + Checks if opcode handler is present
 +/
bool hasOpcodeHandler(Opcode op)
{
    return (op in handlers) != null;
}

/++
 + Reads packetData from a given packet
 +/
void[] read(Packet!true packet, Opcode opcode)
{
    HandlerEntry handlerEntry = handlers[opcode];
    void[] packetData = (handlerEntry.typeInfo.init()).dup;
    void delegate(Packet!true) caller;
    caller.ptr = packetData.ptr;
    caller.funcptr = handlerEntry.inputHandler;
    caller(packet);
    return packetData;
}

/++
 + Writes given packetData to a packet
 +/
void write(Packet!false packet, Opcode opcode, void[] packetData)
{
    HandlerEntry handlerEntry = handlers[opcode];
    assert(packetData.length == handlerEntry.typeInfo.tsize());
    void delegate(Packet!false) caller;
    caller.ptr = packetData.ptr;
    caller.funcptr = handlerEntry.outputHandler;
    caller(packet);
}

unittest {
    /*SmsgAuthChallenge test;
    test.test();
    write();
    SmsgAuthChallenge empty;
    read(Opcode.*/
}