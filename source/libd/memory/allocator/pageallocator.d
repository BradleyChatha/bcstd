module libd.memory.allocator.pageallocator;
import libd.threading.locks, libd.util.errorhandling;
import libd.datastructures.bitkeeper, libd.datastructures.linkedlist;

struct PageAllocation
{
    ubyte[] memory;   // Does NOT include guard pages.
    size_t pageCount; // ^^
    bool hasGuardPage;
    BitKeeperSlice bitKeepSlice;
}

// This allocator doesn't follow the standard allocator API, since it's intended to be used for more
// specialised purposes rather than general allocations.
shared struct PageAllocator
{
    __gshared @nogc nothrow:

    private LockBusyCas _regionLock; // Only really needed for inserts
    private LinkedList!PageRegion _regions;

    private static void newRegion()
    {
        auto region = PageRegion("dummy");
        _regions.moveTail(region);
    }

    static shared(PageAllocation) allocInPages(size_t pageCount, bool allocGuardPage = true)
    {
        _regionLock.lock();
        {
            scope(exit) _regionLock.unlock();
            if(_regions.length == 0)
                newRegion();
        }

        while(true)
        {
            foreach(ref region; _regions.range)
            {
                auto result = region.allocInPages(pageCount, allocGuardPage);
                if(!result.isValid)
                    continue;
                return result.value;
            }
            newRegion();
        }
    }

    static shared(PageAllocation) allocInBytesToPages(size_t minByteCount, bool allocGuardPage = true)
    {
        import libd.util.maths : alignTo;
        // TEMP, fix this later when I can be arsed.
        return allocInPages(minByteCount.alignTo!0x1000 / 0x1000, allocGuardPage);
    }

    static void free(ref shared(PageAllocation) alloc)
    {
        // TODO: determine which region alloc belongs to.
        //       this is safe enough for now.
        if(_regions.length > 1)
            assert(false);
        _regions.getAt(0).free(alloc);
        alloc = PageAllocation.init;
    }
}

unittest
{
    auto alloc = PageAllocator.allocInPages(2);
    PageAllocator.free(alloc);
}

private:

version(Windows)
struct PageRegion
{
    import runtime.system.windows;

    @nogc nothrow:

    ubyte[] memoryRange;
    LockBusyCas bitKeepLock;
    BitKeeper bitKeep;
    uint pageSize;

    this(string _)
    {
        SYSTEM_INFO sysInfo;
        GetSystemInfo(&sysInfo);

        const pageSize       = sysInfo.dwPageSize;              // Size of each page
        const pageGran       = sysInfo.dwAllocationGranularity; // Virtual memory granularity
        const pagesPerGran   = pageGran / pageSize;             // How many pages fit into each granularity
        const trackablePages = pageSize * 8;                    // How many pages in total we can track using a single page as the bitkeep
        const totalPages     = (trackablePages / pagesPerGran) * pagesPerGran;   // How many pages we should actually get under the memory granularity.

        auto ptr = cast(ubyte*)VirtualAlloc(null, totalPages * pageSize, MEM_RESERVE, PAGE_READWRITE);
        if(!ptr)
            onOutOfMemoryError(ptr);
        this.memoryRange = ptr[0..totalPages * pageSize];
        
        if(!VirtualAlloc(ptr, pageSize, MEM_COMMIT, PAGE_READWRITE))
            assert(false, "Did I fuck up the params?");

        this.bitKeep = BitKeeper(memoryRange[0..pageSize], pageSize*8);
        this.bitKeep.alloc(1); // Always keep the first page allocated
        this.pageSize = pageSize;
    }

    SimpleResult!(shared PageAllocation) allocInPages(size_t pageCount, bool allocGuardPage)
    {
        PageAllocation alloc;
        
        this.bitKeepLock.lock();
        {
            scope(exit) this.bitKeepLock.unlock();
            auto result = this.bitKeep.alloc(pageCount + allocGuardPage);
            if(!result.isValid)
                return typeof(return)(result.error);
            alloc.bitKeepSlice = result.value;
        }

        const start = (this.pageSize * alloc.bitKeepSlice.bitIndex);
        const size  = (this.pageSize * pageCount);
        auto ptr = this.memoryRange.ptr + start;
        if(!VirtualAlloc(ptr, size + (this.pageSize * allocGuardPage), MEM_COMMIT, PAGE_READWRITE))
            assert(false, "Did I fuck up the params/maths?");

        if(allocGuardPage)
        {
            DWORD _1;
            if(!VirtualProtect(ptr, this.pageSize, PAGE_READONLY | PAGE_GUARD, &_1))
                assert(false, "Que?");
            alloc.memory = ptr[this.pageSize..this.pageSize+size];
        }
        else
            alloc.memory = ptr[0..size];
        alloc.hasGuardPage = allocGuardPage;
        alloc.pageCount = pageCount;
        return typeof(return)(cast(shared)alloc);
    }

    void free(shared PageAllocation alloc)
    {
        assert(alloc.bitKeepSlice != (shared BitKeeperSlice).init);

        this.bitKeepLock.lock();
        {
            scope(exit) this.bitKeepLock.unlock();
            this.bitKeep.free(alloc.bitKeepSlice);
        }

        if(!VirtualFree(cast(ubyte*)alloc.memory.ptr, alloc.memory.length, MEM_DECOMMIT))
            assert(false, "Could not free pages?");
    }
}

version(Posix)
struct PageRegion // Technically speaking I could DRY this, since I only need to replace bits and bobs.
                  // But I've been programming for about 14 hours and my mind is mush.
                  // TODO: 
{
    import runtime.system.posix;

    @nogc nothrow:

    ubyte[] memoryRange;
    LockBusyCas bitKeepLock;
    BitKeeper bitKeep;
    uint pageSize;

    this(string _)
    {
        const pageSize       = g_posixPageSize;                 // Size of each page
        const pageGran       = g_posixPageSize;                 // Virtual memory granularity
        const pagesPerGran   = pageGran / pageSize;             // How many pages fit into each granularity
        const trackablePages = pageSize * 8;                    // How many pages in total we can track using a single page as the bitkeep
        const totalPages     = (trackablePages / pagesPerGran) * pagesPerGran;   // How many pages we should actually get under the memory granularity.

        auto ptr = cast(ubyte*)mmap(null, totalPages * pageSize);
        if(!ptr)
            onOutOfMemoryError(ptr);
        this.memoryRange = ptr[0..totalPages * pageSize];

        this.bitKeep = BitKeeper(memoryRange[0..pageSize], pageSize*8);
        this.bitKeep.alloc(1); // Always keep the first page allocated
        this.pageSize = pageSize;
    }

    SimpleResult!(shared PageAllocation) allocInPages(size_t pageCount, bool allocGuardPage)
    {
        PageAllocation alloc;
        
        this.bitKeepLock.lock();
        {
            scope(exit) this.bitKeepLock.unlock();
            auto result = this.bitKeep.alloc(pageCount + allocGuardPage);
            if(!result.isValid)
                return typeof(return)(result.error);
            alloc.bitKeepSlice = result.value;
        }

        const start = (this.pageSize * alloc.bitKeepSlice.bitIndex);
        const size  = (this.pageSize * pageCount);
        auto ptr = this.memoryRange.ptr + start;

        if(allocGuardPage)
        {
            // TODO:
            // DWORD _1;
            // if(!VirtualProtect(ptr, this.pageSize, PAGE_READONLY | PAGE_GUARD, &_1))
            //     assert(false, "Que?");
            // alloc.memory = ptr[this.pageSize..this.pageSize+size];
        }
        else
            alloc.memory = ptr[0..size];
        alloc.hasGuardPage = allocGuardPage;
        alloc.pageCount = pageCount;
        return typeof(return)(cast(shared)alloc);
    }

    void free(shared PageAllocation alloc)
    {
        assert(alloc.bitKeepSlice != (shared BitKeeperSlice).init);

        this.bitKeepLock.lock();
        {
            scope(exit) this.bitKeepLock.unlock();
            this.bitKeep.free(alloc.bitKeepSlice);
        }
    }
}