module libd.memory.allocator.systemallocator;

import libd.memory.ptr : MaybeNullPtr, MaybeNullSlice, NotNullSlice, NotNullPtr;

@nogc nothrow
shared struct SystemAllocator
{
    static immutable string Tag = "system";

    enum AllocIsStatic = true;

    // Large amount of user trust.
    @nogc nothrow:

    @trusted
    static MaybeNullSlice!(T, Tag) alloc(T)(size_t amount)
    {
        auto ptr = allocImpl!T(amount);
        if(ptr is null)
            return typeof(return)(null);
        else
            return typeof(return)(ptr[0..amount]);
    }

    @trusted
    static void free(T)(ref NotNullSlice!(T, Tag) slice)
    {
        if(!freeImpl!T(slice.ptr))
            assert(false, "HeapFree failed. `slice` might be null or points to freed/invalid memory.");
        slice.slice = null;
    }

    @trusted
    static void free(T)(ref NotNullPtr!(T, Tag) ptr)
    {
        freeImpl!T(ptr);
        ptr.ptr = null;
    }

    @trusted
    static MaybeNullSlice!(T, Tag) realloc(T)(ref NotNullSlice!(T, Tag) slice, size_t toAmount)
    {
        auto ptr = reallocImpl!T(slice.ptr, slice.length, toAmount);
        slice.slice = null;
        if(ptr is null)
            return typeof(return)(null);
        else
            return typeof(return)(ptr[0..toAmount]);
    }
}

import libd.memory.allocator._test;
@("SystemAllocator - BasicAllocatorTests")
unittest { basicAllocatorTests!(SystemAllocator, () => true)(); } 

void _d_systemAllocInit()
{
    version(Posix)
    {
        g_posixAlloc.__ctor(32);
    }
}

private:

version(Windows)
{
    @nogc nothrow:

    import runtime.system.windows;
    
    T* allocImpl(T)(size_t amount)
    {
        return cast(T*)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, T.sizeof * amount);
    }

    bool freeImpl(T)(T* ptr)
    {
        return !!HeapFree(GetProcessHeap(), 0, ptr);
    }

    T* reallocImpl(T)(T* ptr, size_t fromAmount, size_t toAmount)
    {
        return cast(T*)HeapReAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, ptr, T.sizeof * toAmount);
    }
}
else version(Posix)
{
    import runtime.system.posix;
    import libd.memory;

    // For now. I need to make this better of course.
    private shared BlockBucketAllocator!64 g_posixAlloc;

    T* allocImpl(T)(size_t amount)
    {
        auto p = g_posixAlloc.alloc!T(amount);
        return cast(T*)p;
    }

    bool freeImpl(T)(T* ptr)
    {
        // Idk, somehow this is a circular reference. Will need to look into it at *some* point.
        // if(ptr is null || !g_posixAlloc.owns(ptr))
        //     return false;
        // g_posixAlloc.free(ptr);
        return true;
    }

    T* reallocImpl(T)(T* ptr, size_t fromAmount, size_t toAmount)
    {
        auto slice = ptr[0..T.sizeof * fromAmount].notNull!(g_posixAlloc.Tag);
        auto result = g_posixAlloc.realloc(slice, toAmount);
        if(result is null)
            return null;

        if(toAmount > fromAmount)
        {
            const difference = (toAmount - fromAmount);
            memset(0, result.ptr + (fromAmount * T.sizeof), difference * T.sizeof);
        }

        return result.ptr;
    }
}