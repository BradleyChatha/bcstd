module libd.util.maths;

import libd.meta.traits;

T alignTo(alias Boundary, T)(T value) pure
{
    static if(isPowerOfTwo(Boundary))
        return (value + (Boundary * (value % Boundary > 0))) & ~(Boundary-1);
    else static assert(false, "TODO");
}
///
@("alignTo")
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
///
@("isPowerOfTwo")
unittest
{
    assert(2.isPowerOfTwo);
    assert(4.isPowerOfTwo);
    assert(128.isPowerOfTwo);
    assert(!3.isPowerOfTwo);
}

UnsignedOf!NumT abs(NumT)(NumT value)
{
    static if(__traits(isIntegral, NumT))
        return cast(typeof(return))(value * ((value > 0) - (value < 0)));
    else static assert(false, "Don't know how to abs type '"~NumT.stringof~"'");
}
///
@("abs")
unittest
{
    assert(0.abs == 0);
    assert(1.abs == 1);
    assert((-1).abs == 1);
    assert((-128).abs!byte == 128);
}