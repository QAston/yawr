module util.state_ref.d;

import std.array;
import std.traits;

/++
+ Holds a const reference to a class object
+ Allows queuing state transformations on that object
+ Useful for preventing "spooky action at a distance" common in OO when dealing with non-hierarchical program strucutre
+/
final class StateRef(TYPE) if (is(TYPE == class))
{
	this(TYPE state)
	{
		this.state = state;
	}

    /++
    + Returns const ref to the object held by this reference
    +/
	@property const(TYPE) get()
	{
		return this.state;
	}
	
    /++
    + Queues a transformation on a object held by StateRef
    + All queued transformations will be executed in sequence later on the object
    + A transformation should check if the object is in a desired state before applying changes
    +/
	void queue(void delegate(TYPE) transform)
	{
        transformations.put(transform);
	}

    /++
    + Applies all transforms queued using queueTransform method
    + Requires mutuable reference to the type
    + Transform storage is empties, so instance can be reused
    +/
    void applyTransforms(TYPE t)
    in
    {
        assert(t is state);
    }
    body 
    {
        foreach (transformation ; transformations.data())
        {
            transformation(t);
        }
        transformations.clear();
    }
private:
	const TYPE state;
	Appender!(void delegate(TYPE)[]) transformations;
}

unittest {

    final class State
    {
        string c = "no";
    }

    auto s = new State();
    auto sr = new StateRef!State(s);

    sr.queue((State s){s.c = "yes";});
    sr.applyTransforms(s);
    assert(s.c == "yes");
}