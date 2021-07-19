module runtime.primitives.memory;

extern(C) void _memset32(uint* uints, uint value, size_t length)
{
    for(size_t i = 0; i < length; i++)
        uints[i] = value;
}