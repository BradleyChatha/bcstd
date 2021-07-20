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

// https://stackoverflow.com/a/11398748
private const uint[32] tab32 = [
     0,  9,  1, 10, 13, 21,  2, 29,
    11, 14, 16, 18, 22, 25,  3, 30,
     8, 12, 20, 28, 15, 17, 24,  7,
    19, 27, 23,  6, 26,  5,  4, 31];
private uint log2_32 (uint value) @safe @nogc nothrow pure
{
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    value |= value >> 8;
    value |= value >> 16;
    return tab32[cast(uint)(value*0x07C4ACDD) >> 27];
}
private const uint[64] tab64 = [
    63,  0, 58,  1, 59, 47, 53,  2,
    60, 39, 48, 27, 54, 33, 42,  3,
    61, 51, 37, 40, 49, 18, 28, 20,
    55, 30, 34, 11, 43, 14, 22,  4,
    62, 57, 46, 52, 38, 26, 32, 41,
    50, 36, 17, 19, 29, 10, 13, 21,
    56, 45, 25, 31, 35, 16,  9, 12,
    44, 24, 15,  8, 23,  7,  6,  5];
private uint log2_64 (ulong value) @safe @nogc nothrow pure
{
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    value |= value >> 8;
    value |= value >> 16;
    value |= value >> 32;
    return tab64[(cast(ulong)((value - (value >> 1))*0x07EDD5E59A4E28C2)) >> 58];
}

uint log2(T)(const T value)
{
    alias VT = typeof(value);
    static if(is(VT == const int) || is(VT == const uint))
        return log2_32(value);
    else static if(is(VT == const long) || is(VT == const ulong))
        return log2_64(value);
    else
        static assert(false, "Don't know how to log2 type: "~T.stringof);
}

IntT ceilToInt(IntT)(double value)
{
    const isNegative = value < 0;
    const isWhole = value % 1 == 0;
    return cast(IntT)value + (
        (1 * (-1 * isNegative)) * !isWhole
    );
}