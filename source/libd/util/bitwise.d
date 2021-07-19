module libd.util.bitwise;

T rol(T)(const T value, const uint count)
{
    assert(count < 8 * T.sizeof);
    if (count == 0)
        return cast(T) value;

    return cast(T)((value << count) | (value >> (T.sizeof * 8 - count)));
}