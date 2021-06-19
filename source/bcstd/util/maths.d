module bcstd.util.maths;

T alignTo(alias Boundary, T)(T value) pure
{
    static if(isPowerOfTwo(Boundary))
        return (value + (Boundary * (value % Boundary > 0))) & ~(Boundary-1);
    else static assert(false, "TODO");
}
@("align16")
unittest
{
    assert(alignTo!16(0) == 0);
    assert(alignTo!16(16) == 16);
    assert(alignTo!16(8) == 16);
    assert(alignTo!16(31) == 32);
}

bool isPowerOfTwo(T)(T value)
{
    return (value != 0) && (value & (value - 1)) == 0;
}