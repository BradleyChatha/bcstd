module libd.memory.allocator.regionallocator;

import libd.memory, libd.threading;

shared struct RegionAllocator
{
    static immutable string Tag = "region";

    @disable this(this){}

    @nogc nothrow:

    private
    {
        PageAllocation _alloc;
        size_t _ptr;
        LockBusyCas _ptrLock;
    }

    this(size_t regionSize)
    {
        this._alloc = PageAllocator.allocInBytesToPages(regionSize, false);
    }

    ~this()
    {
        if(this._alloc.memory.ptr)
            PageAllocator.free(this._alloc);
    }

    MaybeNullSlice!(T, Tag) alloc(T)(size_t amount)
    {
        this._ptrLock.lock();
        scope(exit) this._ptrLock.unlock();

        const end = (T.sizeof * amount) + this._ptr;
        if(end > this._alloc.memory.length)
            return typeof(return)(null);

        auto slice = (cast(T*)this._alloc.memory[this._ptr..end].ptr)[0..amount];
        this._ptr = end;
        return typeof(return)(slice);
    }

    void free(T)(ref NotNullSlice!(T, Tag) slice)
    {
    }

    void free(T)(ref NotNullPtr!(T, Tag) ptr)
    {
    }

    MaybeNullSlice!(T, Tag) realloc(T)(ref NotNullSlice!(T, Tag) slice, size_t toAmount)
    {
        auto end = slice.ptr + slice.length;
        if(end != this._ptr)
            return typeof(return)();
        end += T.sizeof * toAmount;
        if(end > this._alloc.memory.length)
            return typeof(return)();
        this._ptr = end;
        return typeof(return)(slice.ptr[0..end]);
    }
}

@("RegionAllocator - BasicAllocatorTests")
unittest 
{ 
    import libd.memory.allocator._test;
    auto alloc = RegionAllocator(4096);
    basicAllocatorTests!(RegionAllocator, () => &alloc)(); 
} 