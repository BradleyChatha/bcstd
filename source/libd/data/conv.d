module libd.data.conv;

import libd.datastructures.string, libd.util.maths, libd.util.errorhandling,  libd.meta, libd.algorithm;

private enum MAX_SIZE_T_STRING_LEN = "18446744073709551615".length;
alias IntToCharBuffer = char[MAX_SIZE_T_STRING_LEN];

private immutable BASE10_CHARS = "0123456789";

String to(StringT : String, ValueT)(auto ref ValueT value)
{
    static if(__traits(compiles, toBase10(value)))
        return value.toBase10;
    else static if(is(ValueT == struct))
    {
        String output;
        structToString(value, output);
        return output;
    }
    else static if(is(ValueT : bcstring))
        return String(value);
    else static if(is(ValueT == String))
        return value;
    else static if(is(ValueT == bool))
        return value ? String("true") : String("false");
    else static assert(false, "Don't know how to convert '"~ValueT.stringof~"' into a String.");
}
///
@("to!String")
unittest
{
    static struct S
    {
        int a;
        string b;
        bool c;
    }

    static struct SS
    {
        string name;
        S s;
    }

    assert(127.to!String == "127");
    assert(S(29, "yolo", true).to!String == `S(29, "yolo", true)`);
    assert(SS("ribena cow", S(69, "swag", false)).to!String == `SS("ribena cow", S(69, "swag", false))`);
}

SimpleResult!NumT to(NumT, ValueT)(ValueT value)
if(__traits(isIntegral, NumT))
{
    static if(is(ValueT : bcstring))
        return fromBase10!NumT(value);
    else static if(is(ValueT == String))
        return fromBase10!NumT(value.range);
    else static assert(false, "Don't know how to convert `"~ValueT.stringof~"` into a `"~NumT.stringof~"`");
}
///
@("to!NumT")
unittest
{
    assert("69".to!int.assumeValid == 69);
    assert(String("-120").to!byte.assumeValid == -120);
}

private void structToString(StructT, OutputT)(auto ref StructT value, ref OutputT output)
if(is(StructT == struct) && isOutputRange!(OutputT, bcstring))
{
    output.put(__traits(identifier, StructT));
    output.put("(");
    foreach(i, ref v; value.tupleof)
    {{
        static if(is(typeof(v) : bcstring) || is(typeof(v) == String))
        {
            output.put("\"");
            output.put(v);
            output.put("\"");
        }
        else
        {
            String s = to!String(v);
            output.put(s.range);
        }

        static if(i < StructT.tupleof.length-1)
            output.put(", ");
    }}
    output.put(")");
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

SimpleResult!NumT fromBase10(NumT)(bcstring str)
{
    if(str.length == 0)
        return raise("String is null.").result!NumT;

    ptrdiff_t cursor = cast(ptrdiff_t)str.length-1;
    
    const firstDigit = str[cursor--] - '0';
    if(firstDigit >= 10 || firstDigit < 0)
        return raise("String contains non-base10 characters.").result!NumT;

    NumT result = cast(NumT)firstDigit;
    uint exponent = 10;
    while(cursor >= 0)
    {
        if(cursor == 0 && str[cursor] == '-')
        {
            static if(__traits(isUnsigned, NumT))
                return raise("Cannot convert a negative number into an unsigned type.").result!NumT;
            else
            {
                result *= -1;
                break;
            }
        }

        const digit = str[cursor--] - '0';
        if(digit >= 10 || digit < 0)
            return raise("String contains non-base10 characters.").result!NumT;

        const oldResult = result;
        result += digit * exponent;
        if(result < oldResult)
            return raise("Overflow. String contains a number greater than can fit into specified numeric type.").result!NumT;

        exponent *= 10;
    }

    return result.result;
}
///
@("fromBase10")
unittest
{
    assert(!fromBase10!int(null).isValid);
    assert(fromBase10!int("0").assumeValid == 0);
    assert(fromBase10!int("1").assumeValid == 1);
    assert(fromBase10!int("21").assumeValid == 21);
    assert(fromBase10!int("321").assumeValid == 321);
    assert(!fromBase10!ubyte("256").isValid);
    assert(fromBase10!ubyte("255").assumeValid == 255);
    assert(!fromBase10!int("yolo").isValid);
    assert(!fromBase10!uint("-20").isValid);
    assert(fromBase10!int("-231").assumeValid == -231);
}