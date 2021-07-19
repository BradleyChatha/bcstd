module libd.algorithm.search;
import  libd.algorithm, libd.util.cpuid;

const INDEX_NOT_FOUND = size_t.max; // Since our only target is x86_64, we can account for the fact it's literally impossible for a memory address to be this value.

@nogc nothrow:

// Using NASM because D's inline ASM, and even core.simd, don't support things like vpbroadcastb, so....
@trusted
private extern(C) ulong indexOfByteAvx2(const(ubyte)* haystack, ulong haystackSize, ubyte* needle, ulong* remainingChars);
@("indexOfByteAvx2")
unittest
{
    if(cpuidHasAvx2)
    {
        size_t remainingChars;
        ubyte needle = ' ';
        assert(indexOfByteAvx2(null, 0, &needle, &remainingChars) == INDEX_NOT_FOUND);
        assert(indexOfByteAvx2(cast(const ubyte*)"                                ".ptr, 32, &needle, &remainingChars) == 0);
        assert(indexOfByteAvx2(cast(const ubyte*)"0123                            ".ptr, 32, &needle, &remainingChars) == 4);

        remainingChars = 33;
        needle = '_';
        assert(indexOfByteAvx2(cast(const ubyte*)"0123                            _".ptr, 33, &needle, &remainingChars) == INDEX_NOT_FOUND);
        assert(remainingChars == 1);

        assert(indexOfByteAvx2(cast(const ubyte*)"0123                            _123                            ".ptr, 64, &needle, &remainingChars) == 32);
        needle = '6';
        assert(indexOfByteAvx2(cast(const ubyte*)"0123                            _126                            ".ptr, 64, &needle, &remainingChars) == 35);
    }
}

@trusted
size_t indexOfAscii(scope const bcstring haystack, char asciiChar)
{
    assert((asciiChar & 0b1000_0000) == 0, "This function does not support searching for UTF chars.");

    size_t remainingChars = haystack.length;

    if(cpuidHasAvx2 && remainingChars >= 32)
    {
        const result = indexOfByteAvx2(cast(const ubyte*)haystack.ptr, haystack.length, cast(ubyte*)&asciiChar, &remainingChars);
        if(result != INDEX_NOT_FOUND)
            return result;
    }

    for(size_t i = haystack.length-remainingChars; i < haystack.length; i++)
    {
        if(haystack[i] == asciiChar)
            return i;
    }

    return INDEX_NOT_FOUND;
}
///
@("indexOfAscii")
unittest
{
    assert("0123456789".indexOfAscii('0') == 0);
    assert("0123456789".indexOfAscii('9') == 9);
    assert("0123456789".indexOfAscii('4') == 4);

    assert("The quick brown fox jumped over the lazy dog.".indexOfAscii('d') == 25);
    assert("The quick brown fox jumped over the lazy dog.".indexOfAscii('z') == 38);
}

size_t indexOf(alias Comparator, HaystackT, NeedleT)(const auto ref HaystackT haystack, const auto ref NeedleT needle)
if(canForeachOrProvidesRange!HaystackT)
{
    import libd.meta : ElementType;

    static if(!canForeach!HaystackT)
        auto range = haystack.range;
    else
        alias range = haystack;

    static immutable IMPL = q{
        if(value == needle)
            return index;
        index++;
    };

    size_t index;
    static if(!is(ElementType!range == struct) || __traits(isPOD, ElementType!range))
    {
        foreach(value; range)
            mixin(IMPL);
    }
    else
    {
        foreach(ref value; range)
            mixin(IMPL);
    }

    return INDEX_NOT_FOUND;
}
///
@("indexOf")
unittest
{
    import libd.datastructures.string, libd.datastructures.array;

    Array!char arr;
    arr.put("0123456789");

    assert("0123456789".indexOf('0') == 0);
    assert(String("0123456789").indexOf('9') == 9);
    assert(arr.indexOf('4') == 4);

    assert("The quick brown fox jumped over the lazy dog.".indexOf('d') == 25);
    assert("The quick brown fox jumped over the lazy dog.".indexOf('z') == 38);
}

size_t indexOf(HaystackT, NeedleT, alias Comparator = (a,b) => a == b)(const auto ref HaystackT haystack, const auto ref NeedleT needle)
{
    return indexOf!Comparator(haystack, needle);
}