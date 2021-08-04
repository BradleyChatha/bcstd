module libd.memory.allocator.blockallocator;

import libd.memory, libd.datastructures, libd.threading;

@(OnMove.forbid)
shared struct BlockBucketAllocator(size_t size)
{
    @disable this(this);
    @disable this(scope const ref typeof(this)){}

    static immutable string Tag = "block_bucket_alloc";

    private
    {
        static struct Node
        {
            BlockAllocator!size alloc;
            Node* next;
        }

        Node* _head;
        Node* _tail;
        shared RegionAllocator _nodeAllocBase;
        shared AllocatorWrapperOf!(typeof(_nodeAllocBase)) _nodeAlloc;
        size_t _pageFactor;
    }

    @nogc nothrow:

    this(size_t pageFactor)
    {
        this._nodeAllocBase = typeof(_nodeAllocBase)(pageFactor);
        this._nodeAlloc = typeof(_nodeAlloc)(&this._nodeAllocBase);
        this._pageFactor = pageFactor;
        this.newNode();
    }

    ~this()
    {
        while(this._head !is null)
        {
            this._head.alloc.__xdtor();
            this._head = this._head.next;
        }
    }

    MaybeNullSlice!(T, Tag) alloc(T)(size_t amount)
    {
        if(amount > this._head.alloc._maxAlloc)
            return typeof(return)(null);

        auto curr = this._head;
        while(curr !is null)
        {
            auto alloc = curr.alloc.alloc!T(amount);
            if(alloc !is null)
                return typeof(return)(alloc.slice);
            curr = curr.next;
        }

        curr = this.newNode();
        if(curr is null)
            return typeof(return)(null);
        auto alloc = curr.alloc.alloc!T(amount);
        if(alloc !is null)
            return typeof(return)(alloc.slice);
        
        return typeof(return)(null);
    }

    @safe
    bool owns(void* ptr) pure
    {
        auto curr = this._head;
        while(curr !is null)
        {
            if(curr.alloc.owns(ptr))
                return true;
            curr = curr.next;
        }

        return false;
    }

    void free(T)(ref NotNullSlice!(T, Tag) slice)
    {
        this.free(slice.ptr);
        slice.slice = null;
    }

    void free(T)(ref NotNullPtr!(T, Tag) ptr)
    {
        this.free(ptr.ptr);
        ptr.ptr = null;
    }
    
    void free(T)(T* ptr)
    {
        auto curr = this._head;
        while(curr !is null)
        {
            if(curr.alloc.owns(ptr))
            {
                curr.alloc.free!T(ptr);
                return;
            }
            curr = curr.next;
        }

        assert(false, "Pointer does not belong to this allocator.");
    }

    MaybeNullSlice!(T, Tag) realloc(T)(ref NotNullSlice!(T, Tag) slice, size_t toAmount)
    {
        // Step one: see if the owner bucket can reallocate first.
        auto curr = this._head;
        while(curr !is null)
        {
            if(curr.alloc.owns(slice.ptr))
            {
                auto copy = slice.notNull!"block_alloc";
                auto result = curr.alloc.realloc!T(copy, toAmount);
                if(result !is null)
                {
                    slice = copy;
                    return typeof(return)(result);
                }
                break;
            }
            curr = curr.next;
        }

        // Otherwise try to reallocate using any other allocator.
        auto newBlock = this.alloc!T(toAmount);
        if(newBlock is null)
            return typeof(return)();

        if(toAmount < slice.length)
            memcpy(slice.ptr, newBlock.ptr, toAmount * T.sizeof);
        else
            memcpy(slice.ptr, newBlock.ptr, slice.length * T.sizeof);

        curr.alloc.free(slice.ptr);
        return typeof(return)(newBlock);
    }

    private shared(Node*) newNode()
    {
        auto node = this._nodeAlloc.make!Node;
        if(node is null)
            return null;
        emplaceCtor(node.alloc, this._pageFactor);

        if(this._head is null)
        {
            this._head = cast(shared)node;
            this._tail = cast(shared)node;
        }
        else
        {
            this._tail.next = cast(shared)node;
            this._tail = cast(shared)node;
        }

        return cast(shared)node.ptr;
    }
}

shared struct BlockAllocator(size_t size)
{
    @disable this(this);

    private
    {
        PageAllocation _alloc;
        Lockable!BitKeeper _bits;
        size_t _dataStart;
        size_t _maxAlloc;
    }

    static immutable string Tag = "block_alloc";

    @nogc nothrow:

    this(size_t pageFactor)
    {
        const pagesPerSize          = ((size / memoryPageSize) + 1) * pageFactor;
        const bytesPerPagesPerSize  = pagesPerSize * size * memoryPageSize;
        const bitsNeededForKeeper   = bytesPerPagesPerSize / size;
        const pagesForKeeperBits    = (bitsNeededForKeeper / memoryPageSize) + 1;
        const pagesTotal            = pagesForKeeperBits + pagesPerSize;

        this._alloc = cast(shared)PageAllocator.allocInPages(pagesTotal, false);
        this._dataStart = pagesForKeeperBits * memoryPageSize;
        this._maxAlloc  = pagesPerSize * memoryPageSize;
        this._bits.access((ref bits)
        {
            bits = BitKeeper(cast(ubyte[])this._alloc.memory[0..this._dataStart], bitsNeededForKeeper);
        });
    }

    ~this()
    {
        if(this._alloc.memory.ptr)
            PageAllocator.free(this._alloc);
    }

    MaybeNullSlice!(T, Tag) alloc(T)(size_t amount)
    {
        const blocksForAmount = ((amount + BitKeeperSlice.sizeof) / size) + 1;
        SimpleResult!BitKeeperSlice slice;
        this._bits.access((ref bits)
        {
            slice = bits.alloc(blocksForAmount);
        });
        if(!slice.isValid)
            return typeof(return)(null);

        auto bitSlice = slice.value;
        const start = this._dataStart + (bitSlice.bitIndex * size);
        const end   = start + BitKeeperSlice.sizeof + amount;
        if(end > this._alloc.memory.length)
            return typeof(return)(null);
        auto ptr = cast(ubyte[])this._alloc.memory[start..end];
        *(cast(BitKeeperSlice*)ptr) = bitSlice;
        return typeof(return)(cast(T[])(cast(T*)ptr[BitKeeperSlice.sizeof..$].ptr)[0..amount]);
    }

    @safe
    bool owns(void* ptr) pure
    {
        return ptr >= this._alloc.memory.ptr && ptr <= &this._alloc.memory[$-1];
    }

    void free(T)(ref NotNullSlice!(T, Tag) slice)
    {
        this.free(slice.ptr);
        slice.slice = null;
    }

    void free(T)(ref NotNullPtr!(T, Tag) ptr)
    {
        this.free(ptr.ptr);
        ptr.ptr = null;
    }

    void free(T)(T* ptr)
    {
        // I might have hit a codegen bug doing this a more logical way,
        // Instead of subtracting 24 it adds like 200
        auto ptr1 = cast(ulong)ptr;
        ptr1 -= BitKeeperSlice.sizeof;
        const ptr2 = cast(BitKeeperSlice*)ptr1;
        const slice = *ptr2;
        this._bits.access((ref bits)
        {
            bits.free(slice);
        });
    }

    MaybeNullSlice!(T, Tag) realloc(T)(ref NotNullSlice!(T, Tag) slice, size_t toAmount)
    {
        if(slice.length == toAmount)
            return slice.maybeNull!Tag;

        // Naive implementation. We could do quite a bit better than this.
        auto newBlock = this.alloc!T(toAmount);
        if(newBlock is null)
            return typeof(return)(null);

        if(toAmount < slice.length)
            memcpy(slice.ptr, newBlock.ptr, toAmount * T.sizeof);
        else
            memcpy(slice.ptr, newBlock.ptr, slice.length * T.sizeof);

        this.free(slice);
        return newBlock;
    }
}

@("BlockAllocator - BasicAllocatorTests")
unittest 
{ 
    import libd.memory.allocator._test;
    BlockAllocator!1 alloc = BlockAllocator!1(1);
    basicAllocatorTests!(BlockAllocator!1, () => &alloc)(); 
}

@("BlockBucketAllocator - BasicAllocatorTests")
unittest 
{ 
    import libd.memory.allocator._test;
    BlockBucketAllocator!1 alloc = BlockBucketAllocator!1(1);
    basicAllocatorTests!(BlockBucketAllocator!1, () => &alloc)(); 
} 