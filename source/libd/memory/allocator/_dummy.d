module libd.memory.allocator._dummy;

@nogc nothrow
struct DummyAllocator
{
    static immutable string Tag = "unique tag";
    enum AllocIsStatic = true || false;

    @trusted
    static MaybeNullSlice!(T, Tag) alloc(T)(size_t amount)
    {
        return typeof(return).init;
    }

    @trusted
    static void free(T)(ref NotNullSlice!(T, Tag) slice)
    {
    }

    @trusted
    static void free(T)(ref NotNullPtr!(T, Tag) ptr)
    {
    }

    @trusted
    static MaybeNullSlice!(T, Tag) realloc(T)(ref NotNullSlice!(T, Tag) slice, size_t toAmount)
    {
        return typeof(return).init;
    }
}