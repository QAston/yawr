module util.algorithm;

import std.algorithm;

/+
 + Checks if elements in range are unique
 +/
bool elementsUnique(RANGE)(RANGE range)
{
    auto duplicate = range.dup;
    duplicate.sort;
    return duplicate.uniq.equal(duplicate);
}

unittest {
    assert(elementsUnique([5, 7, 4]));
    assert(!elementsUnique([5, 7, 4, 2, 5]));
}