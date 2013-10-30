/++
+ This module provides StateTrans utility which allows you to control when mutation of a passed variable happens
+ Guidelines:
+   pass by const if you don't want mutation
+   pass by mutuable if you want mutation immediately
+   pass by StateTrans if you want mutation but you want to control when it happens
+/
module util.state_trans;

import std.array;
import std.traits;

/++
+ Holds a const reference to a class object and transitions to apply to the state of the object later
+/
final class StateTrans(TYPE) if (is(TYPE == class))
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
    + Queues a transformation on a object held by StateTrans
    + All queued transformations will be executed in sequence later applyTransforms is called
    + A transformation should check if the object is in a desired state before applying changes
    +/
    void queue(void delegate(TYPE) transform)
    {
        transformations.put(transform);
    }

    /++
    + Applies all transforms queued using queue method
    + Requires mutuable reference to the type
    + Transform storage is emptied, so instance can be reused
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
    alias get this;
private:
    const TYPE state;
    Appender!(void delegate(TYPE)[]) transformations;
}

/++
+ Convenience function for StateTrans construction
+/
auto stateTrans(TYPE)(TYPE state)
{
    return new StateTrans!TYPE(state);
}

/++
+ Convenience function returning RAII type for automatic calling of applyTransforms on StateTrans
+/
auto stateTransApply(TYPE)(TYPE state)
{
    struct StateTransRAII
    {
        TYPE t;
        StateTrans!TYPE stateTrans;
        this(TYPE t)
        {
            this.t = t;
            this.stateTrans = new StateTrans!TYPE(t);
        }
        ~this()
        {
            this.stateTrans.applyTransforms(t);
        }
        alias stateTrans this;
    }
    return StateTransRAII(state);
}

unittest {

    final class State
    {
        string c = "no";
    }

    auto s = new State();
    auto st = stateTrans(s);

    st.queue((State s){s.c = "yes";});
    st.applyTransforms(s);
    assert(s.c == "yes");

    
    void func(StateTrans!(State) q)
    {
        assert(q.get.c == "yes");
        q.queue((State s){s.c = "maybe";});
        assert(q.get.c == "yes");
    }

    func(stateTransApply(s));
    assert(s.c == "maybe");
}