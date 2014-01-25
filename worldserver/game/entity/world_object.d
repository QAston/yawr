module worldserver.game.entity.world_object;

import vibe.core.concurrency;

/++
+ WorldObject - base class for all objects present in world
+
+ each object is an actor
+ modification of the actor is done by sending messages to it
+ reading actor state is done by reading properties of the object
+ properties return immutable copy of internal value
+ first read from property creates copy and stores it in Isolated!TYPE to make sure readers get consistent view
+ properties data is kept small to minimize cost of copying
+ all public stuff can be called from other tasks
+/
class WorldObject
{
    // map (id + instance)
    // position
    // object fields
    /+

    void update()
    {
        Duration d = dur!"msecs"(500);

        receiveTimeout(d,
        (){} 
        );
    }

    void accept()
    {
    }+/
}

// this struct helps encapsulation - it's used for storing mutuable obj data and for access by visitors
class WorldObjectInternal
{
}

// sequential execution (across actors) - possibly
// - have multiple queues for each actor, each executed in one "turn", by queuing for later queues sequential execution is achieved
// - or have ack messages
// events:
// - hold only values - only those describing event - should be serializable
// - visitor pattern
// restorable events (possibly) - would allow exact storing of history in db and reapplying it later
// - 2 part apply
// - apply can reject, can do sideffects
// - change just updates the object value, should be pure
interface Event
{
    bool apply();
    void change() pure;
}