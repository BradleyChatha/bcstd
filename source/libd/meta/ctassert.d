module libd.meta.ctassert;

import libd.meta.traits;

template ctassert(bool result, string error)
{
    static assert(result, error);
    enum ctassert = true;
}

alias assertIsPartOfUnion(UnionT, ValueT) = ctassert!(
    isPartOfUnion!(UnionT, ValueT),
    "Type `"~ValueT.stringof~"` does not belong to union `"~UnionT.stringof~"`"
);
///
@("assertIsPartOfUnion")
unittest
{
    static union U
    {
        int a;
    }
    
    static assert(__traits(compiles, assertIsPartOfUnion!(U, int)));
    static assert(!__traits(compiles, assertIsPartOfUnion!(U, string)));
}

alias assertAllSatisfy(alias Condition, T...) = ctassert!(
    allSatisfy!(Condition, T),
    "Not all parameters satisfy condition `"~__traits(identifier, Condition)~"`"  
);
///
@("assertAllSatisfy")
unittest
{
    enum isInt(T) = is(T == int);
    static assert(__traits(compiles, assertAllSatisfy!(isInt, int, int)));
    static assert(!__traits(compiles), assertAllSatisfy!(isInt, int, string, int));
}