module bcstd.util.conv;

import bcstd.datastructures.string, bcstd.util.maths;

private enum MAX_SIZE_T_STRING_LEN = "18446744073709551615".length;
alias IntToCharBuffer = char[MAX_SIZE_T_STRING_LEN];

private immutable BASE10_CHARS = "0123456789";

String to(StringT : String, ValueT)(ValueT value)
{
    static if(__traits(compiles, toBase10(value)))
        return value.toBase10;
    else static assert(false, "Don't know how to convert '"~ValueT.stringof~"' into a String.");
}
///
@("to")
unittest
{
    assert(127.to!String == "127");
}

String toBase10(NumT)(NumT num)
{
    // Fun fact, because of SSO, this will always be small enough to go onto the stack.
    // MAX_SIZE_T_STRING_LEN is 20, small strings are up to 22 chars.
    IntToCharBuffer buffer;
    return String(toBase10(num, buffer));
}
///
@("toBase10 - String return")
unittest
{
    assert((cast(byte)127).toBase10!byte == "127");
    assert((cast(byte)-128).toBase10!byte == "-128");
}

char[] toBase10(NumT)(NumT num, scope ref return IntToCharBuffer buffer)
{
    size_t cursor = buffer.length-1;
    if(num == 0)
    {
        buffer[cursor] = '0';
        return buffer[cursor..$];
    }

    static if(__traits(isScalar, NumT))
    {
        static if(!__traits(isUnsigned, NumT))
        {
            const isNegative = num < 0;
            auto numAbs = num.abs;
        }
        else
            auto numAbs = num;

        while(numAbs != 0)
        {
            buffer[cursor--] = BASE10_CHARS[numAbs % 10];
            numAbs /= 10;
        }

        static if(!__traits(isUnsigned, NumT))
        if(isNegative)
            buffer[cursor--] = '-';
    }
    else static assert(false, "Don't know how to convert '"~NumT.stringof~"' into base-10");

    return buffer[cursor+1..$];    
}
///
@("toBase10")
unittest
{
    IntToCharBuffer buffer;
    assert(toBase10!byte(byte.max, buffer) == "127");
    assert(toBase10!byte(byte.min, buffer) == "-128");
    assert(toBase10!ubyte(ubyte.max, buffer) == "255");
    assert(toBase10!ubyte(ubyte.min, buffer) == "0");

    assert(toBase10!short(short.max, buffer) == "32767");
    assert(toBase10!short(short.min, buffer) == "-32768");
    assert(toBase10!ushort(ushort.max, buffer) == "65535");
    assert(toBase10!ushort(ushort.min, buffer) == "0");

    assert(toBase10!int(int.max, buffer) == "2147483647");
    assert(toBase10!int(int.min, buffer) == "-2147483648");
    assert(toBase10!uint(uint.max, buffer) == "4294967295");
    assert(toBase10!uint(uint.min, buffer) == "0");

    assert(toBase10!long(long.max, buffer) == "9223372036854775807");
    assert(toBase10!long(long.min, buffer) == "-9223372036854775808");
    assert(toBase10!ulong(ulong.max, buffer) == "18446744073709551615");
    assert(toBase10!ulong(ulong.min, buffer) == "0");
}