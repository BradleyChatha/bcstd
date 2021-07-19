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

private:

version(Windows)
{
    @nogc nothrow:

    import runtime.system.windows : HANDLE, DWORD, SIZE_T, LPVOID, BOOL;

    enum HeapAllocFlag : DWORD
    {
        none = 0,
        HEAP_NO_SERIALISE = 1,
        HEAP_GENERATE_EXCEPTIONS = 4,
        HEAP_ZERO_MEMORY = 8,
        HEAP_REALLOC_IN_PLACE_ONLY = 16,
    }

    extern(Windows) HANDLE GetProcessHeap();
    extern(Windows) LPVOID HeapAlloc(HANDLE hHeap, HeapAllocFlag dwFlags, SIZE_T dwBytes);
    extern(Windows) BOOL HeapFree(HANDLE hHeap, DWORD _, LPVOID lpMem);
    extern(Windows) LPVOID HeapReAlloc(HANDLE hHeap, HeapAllocFlag dwFlags, LPVOID lpMem, SIZE_T dwBytes);
    extern(Windows) DWORD GetExceptionCode();
    
    T* allocImpl(T)(size_t amount)
    {
        return cast(T*)HeapAlloc(GetProcessHeap(), HeapAllocFlag.HEAP_ZERO_MEMORY, T.sizeof * amount);
    }

    bool freeImpl(T)(T* ptr)
    {
        return !!HeapFree(GetProcessHeap(), 0, ptr);
    }

    T* reallocImpl(T)(T* ptr, size_t fromAmount, size_t toAmount)
    {
        return cast(T*)HeapReAlloc(GetProcessHeap(), HeapAllocFlag.HEAP_ZERO_MEMORY, ptr, T.sizeof * toAmount);
    }
}
else // Default to libc for platforms without specific support.
{
    import core.stdc.stdlib : calloc, free, realloc;
    import libd.memory.funcs : memset;

    T* allocImpl(T)(size_t amount)
    {
        return cast(T*)calloc(amount, T.sizeof);
    }

    bool freeImpl(T)(T* ptr)
    {
        if(ptr is null)
            return false;
        free(ptr);
        return true;
    }

    T* reallocImpl(T)(T* ptr, size_t fromAmount, size_t toAmount)
    {
        ptr = realloc(ptr, toAmount);
        if(ptr is null)
            return null;

        if(toAmount > fromAmount)
        {
            const difference = (toAmount - fromAmount);
            memset(ptr + (fromAmount * T.sizeof), 0, difference * T.sizeof);
        }

        return ptr;
    }
}