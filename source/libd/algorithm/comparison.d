module libd.algorithm.comparison;

import libd.algorithm;

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
    import libd.datastructures : Array;
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
    import libd.datastructures : LinkedList;
    LinkedList!int list;
    list.put(0, 1, 2, 3, 4, 5, 6);
    assert(list.range.all!(n => n < 10));
    assert(!list.range.all!(n => (n % 2) == 0));
}

bool equals(alias Comparator, Range1, Range2)(Range1 r1, Range2 r2)
{
    while(true)
    {
        if(r1.empty && r2.empty)
            return true;
        else if(r1.empty != r2.empty)
            return false;
        else if(!Comparator(r1.front, r2.front))
            return false;
        r1.popFront();
        r2.popFront();
    }
}
///
@("equals - array==array")
unittest
{
    int[3] array = [1, 2, 3];
    assert(array[0..$].equals!((a,b) => a==b)(array[0..$]));
}