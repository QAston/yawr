module util.protocol.direction;

/+
 + Direction in which messages between client and server are sent, clientToServer and serverToClient
 +/
enum Direction : uint { c2s = 0, s2c = 1,};

template OppositeDirection(Direction dir)
{
    static if (dir == Direction.c2s)
        enum OppositeDirection = Direction.s2c ;
    else
        enum OppositeDirection = Direction.c2s ;
}

static assert (OppositeDirection!(Direction.c2s) == Direction.s2c);
static assert (OppositeDirection!(Direction.s2c) == Direction.c2s);