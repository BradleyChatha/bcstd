module bcstd.algorithm.comparison;

import bcstd.algorithm;

bool any(alias Func, Range)(Range r)
{
    while(!r.empty)
    {
        if(Func(r.front))
            return true;
        r.popFront();
    }
    return false;
}
///
@("any")
unittest
{
    import bcstd.datastructures : Array;
    Array!int array;
    array.put(0, 1, 2, 3, 4, 5, 6);
    assert(array.range.any!(n => n == 6));
    assert(!array.range.any!(n => n > 10));
}

bool all(alias Func, Range)(Range r)
{
    while(!r.empty)
    {
        if(!Func(r.front))
            return false;
        r.popFront();
    }
    return true;
}
///
@("all")
unittest
{
    import bcstd.datastructures : LinkedList;
    LinkedList!int list;
    list.put(0, 1, 2, 3, 4, 5, 6);
    assert(list.range.all!(n => n < 10));
    assert(!list.range.all!(n => (n % 2) == 0));
}