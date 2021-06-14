module bcstd.algorithm.common;

import bcstd.meta : isSlice, ElementType;

@nogc nothrow:

enum isInputRange(alias RangeT) =
(
    __traits(hasMember, RangeT, "front")
 && __traits(hasMember, RangeT, "popFront")
 && __traits(hasMember, RangeT, "empty")
)
 || isSlice!RangeT;

enum isOutputRange(alias RangeT, alias ElementT) =
    __traits(compiles, RangeT.init.put(ElementT.init));

enum isCollection(alias CollectionT, alias ElementT) =
    __traits(hasMember, CollectionT, "insertAt")
 && __traits(hasMember, CollectionT, "removeAt")
 && __traits(hasMember, CollectionT, "getAt")
 && __traits(hasMember, CollectionT, "length")
 && is(typeof(CollectionT.init.getAt(0)) == ElementT)
 && providesRange!CollectionT
 && isOutputRange!(CollectionT, ElementT);

enum providesRange(alias T) = 
    __traits(hasMember, T, "range");

enum OptimisationHint
{
    none = 0,

    rangeFasterThanIndex = 1 << 0,
    preferMoveOverCopy = 1 << 1
}

pragma(inline, true)
bool empty(T)(const scope auto ref T array)
if(isSlice!T)
{
    return array.length == 0;
}

pragma(inline, true)
ElementType!T front(T)(scope auto ref inout(T) array)
if(isSlice!T)
{
    return array[0];
}

pragma(inline, true)
void popFront(T)(scope auto ref T array)
if(isSlice!T)
{
    array = array[1..$];
}