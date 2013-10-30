module util.algorithm;

import std.algorithm;


/+
 + Checks if elements in range are unique
 +/
bool elementsUnique(RANGE)(in RANGE range)
{
    auto duplicate = range.dup;
    duplicate.sort;
    return duplicate.uniq.equal(duplicate);
}

unittest {
    assert(elementsUnique([5, 7, 4]));
    assert(!elementsUnique([5, 7, 4, 2, 5]));
}

import std.range;
import std.functional;
import std.array;

/+
 + Given a range r and some function that maps items in the range to some value type that can be compared with the == operator, 
 + Returns a range of subranges of the original range, such that all the items in each subrange is mapped by the function to the same value
 + Copyright: H. S. Teoh, August 2013
 +/
auto chunkBy(alias attrFun, Range)(Range r)
if (isInputRange!Range &&
    is(typeof(attrFun(ElementType!Range.init) == attrFun(ElementType!Range.init) ))
    )
{
    alias attr = unaryFun!attrFun;
    alias AttrType = typeof(attr(r.front));

    static struct Chunk {
        private Range r;
        private AttrType curAttr;
        @property bool empty() {
            return r.empty || !(curAttr == attr(r.front));
        }
        @property ElementType!Range front() { return r.front; }
        void popFront() {
            assert(!r.empty);
            r.popFront();
        }
    }

    static struct ChunkBy {
        private Range r;
        private AttrType lastAttr;
        this(Range _r) {
            r = _r;
            if (!empty)
                lastAttr = attr(r.front);
        }
        @property bool empty() { return r.empty; }
        @property auto front() {
            assert(!r.empty);
            return Chunk(r, lastAttr);
        }
        void popFront() {
            assert(!r.empty);
            while (!r.empty && attr(r.front) == lastAttr) {
                r.popFront();
            }
            if (!r.empty)
                lastAttr = attr(r.front);
        }
        static if (isForwardRange!Range) {
            @property ChunkBy save() {
                ChunkBy copy;
                copy.r = r.save;
                copy.lastAttr = lastAttr;
                return copy;
            }
        }
    }
    return ChunkBy(r);
}

unittest {
    auto range = [
        [1, 1],
        [1, 1],
        [1, 2],
        [2, 2],
        [2, 3],
        [2, 3],
        [3, 3]
    ];

    auto byX = chunkBy!(a => a[0])(range);
    auto expected1 = [
        [[1, 1], [1, 1], [1, 2]],
        [[2, 2], [2, 3], [2, 3]],
        [[3, 3]]
    ];
    foreach (e; byX) {
        assert(!expected1.empty);
        assert(e.equal(expected1.front));
        expected1.popFront();
    }

    auto byY = chunkBy!(a => a[1])(range);
    auto expected2 = [
        [[1, 1], [1, 1]],
        [[1, 2], [2, 2]],
        [[2, 3], [2, 3], [3, 3]]
    ];
    foreach (e; byY) {
        assert(!expected2.empty);
        assert(e.equal(expected2.front));
        expected2.popFront();
    }
}