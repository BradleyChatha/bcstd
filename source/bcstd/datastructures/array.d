module bcstd.datastructures.array;

import core.exception : onOutOfMemoryError;
import bcstd.memory : AllocatorWrapperOf, SystemAllocator, emplaceInit, maybeNull, dtorSliceIfNeeded, move;
import bcstd.memory.ptr;
import bcstd.meta.traits : isCopyable;
import bcstd.datastructures.growth;

@nogc nothrow 
struct Array(alias T, alias AllocT = SystemAllocator, alias Grow = DefaultGrowth)
{
    // Functions templated to infer attributes from the allocator as well as T's dtor, postblit, and copy ctor attributes.
    // NOTE: The @safety of some of these functions has trust in the allocator's memory always being valid during the lifetime of the Array.

    private AllocatorWrapperOf!AllocT    _alloc;
    private NotNullSlice!(T, AllocT.Tag) _slice;
    private size_t                       _inUse;

    @disable this(this) {}

    this()(AllocatorWrapperOf!AllocT alloc)
    {
        this._alloc = alloc;
    }

    ~this()
    {
        if(this._slice !is null)
            this._alloc.dispose(this._slice);
    }

    void put()(auto ref T value)
    {
        this.growTo(this._inUse + 1);
        this._slice[this._inUse-1] = value;
    }

    void put()(scope T[] values...)
    {
        this.growTo(this._inUse + values.length);
        this._slice[this._inUse-values.length..this._inUse] = values[0..$];
    }

    void put()(scope const(T)[] values...)
    {
        this.growTo(this._inUse + values.length);
        this._slice[this._inUse-values.length..this._inUse] = values[0..$];
    }

    void insertAt()(size_t index, auto ref T value)
    {
        this.growTo(this._inUse+1);
        this[index+1..$] = this[index..$-1];
        this[index] = value;
    }

    void removeAt()(size_t index, scope ref T dest)
    {
        move(this[index], dest);
        this[index..$-1] = this[index+1..$];
        this.shrinkTo(this._inUse-1);
    }

    T removeAt()(size_t index)
    {
        static if(!isCopyable!T)
            pragma(msg, "hint: Since type `"~T.stringof~"` is not copyable, you might want to use the other overload of `removeAt` which performs a memory move.");

        T value;
        this.removeAt(index, value);
        return value;
    }

    ref inout(T) getAt()(size_t index) inout
    {
        assert(index < this._inUse, "Index out of bounds.");
        return this._slice[index];
    }

    void compactMemory()()
    {
        this.shrinkTo!true(this._inUse);
    }

    void reserve(bool useGrowth = false)(size_t amount)
    {
        const inUse = this._inUse;
        this.growTo!useGrowth(this._slice.length + amount);
        this._inUse = inUse;
    }

    @property @trusted // User trust required to not escape slice outside of its lifetime.
    inout(T)[] range() inout
    {
        return this._slice;
    }

    @property
    void length()(size_t value)
    {
        if(value > this._inUse)
            this.growTo(value);
        else
            this.shrinkTo(value);
    }

    @property @safe
    size_t length() const pure
    {
        return this._inUse;
    }

    @property @safe
    size_t capacity() const pure
    {
        return this._slice.length;
    }

    @safe size_t opDollar() const pure { return this.length; }
    @safe inout(T)[] opIndex() inout pure { return this.length == 0 ? null : this._slice[0..this._inUse]; }

    @safe
    ref inout(T) opIndex(size_t index) inout pure
    {
        return this.getAt(index);
    }

    @trusted // Trust the user to not persist the slice longer than its lifetime.
    inout(T)[] opSlice(size_t start, size_t end) inout pure
    {
        assert(end <= this._inUse, "End index is out of bounds.");
        assert(start <= end, "Start index is out of bounds, or is greater than the end index.");
        return this._slice[start..end];
    }

    void opSliceAssign()(auto ref T value, size_t start, size_t end)
    {
        auto slice = this[start..end];
        slice[0..$] = value;
    }

    void opSliceAssign()(scope T[] value, size_t start, size_t end)
    {
        auto slice = this[start..end];
        slice[0..$] = value[0..$];
    }

    private void growTo(bool useGrowth = true)(size_t newAmount)
    {
        assert(newAmount >= this._inUse);
        
        if(this._slice is null) // Ensure we respect the "NotNullSlice" contract.
            this._slice = this._alloc.makeArray!T(Grow.grow(0));

        if(newAmount > this._slice.length)
        {
            static if(useGrowth)
            {
                auto bufferLength = this._slice.length;
                while(bufferLength < newAmount)
                    bufferLength = Grow.grow(bufferLength);
            }
            else
                const bufferLength = newAmount;

            auto result = this._alloc.growArray!T(bufferLength, this._slice);
            if(result is null)
                onOutOfMemoryError(null);
            this._slice = result;
        }
        else
        {
            T init = T.init;
            this._slice[this._inUse..newAmount] = init;
        }

        this._inUse = newAmount;
    }

    private void shrinkTo(bool compactMemory = false)(size_t newAmount)
    {
        assert(newAmount <= this._inUse);
        if(this._slice is null)
            return;
        
        this._slice[newAmount..this._inUse].notNull.dtorSliceIfNeeded();
        
        static if(compactMemory)
        {
            auto result = this._alloc.shrinkArray!T(newAmount, this._slice);
            if(result is null)
                onOutOfMemoryError(null);
            this._slice = result;
        }
        else
        {
            // TODO: Make something like Growth, but for shrinking, to allow customisability.
            if(newAmount <= this._slice.length / 2)
            {
                auto result = this._alloc.shrinkArray!T(this._slice.length / 2, this._slice);
                if(result is null)
                    onOutOfMemoryError(null);
                this._slice = result;
            }
        }

        this._inUse = newAmount;
    }
}
///
@("Array - basic")
unittest
{
    import bcstd.algorithm : isCollection, isInputRange;
    static assert(isCollection!(Array!int, int));
    static assert(isInputRange!(typeof(Array!int.range())));

    const GrowthFirstStep = DefaultGrowth.grow(0);
    const JustBeforeFirstStep = GrowthFirstStep - 1;

    Array!int a;
    a.length = 0;
    a.length = JustBeforeFirstStep;
    assert(a.length == 7);
    assert(a.capacity == GrowthFirstStep);
    a.length = 5;
    assert(a.length == 5);
    assert(a.capacity == GrowthFirstStep);
    a.compactMemory();
    assert(a.capacity == a.length);
    a.reserve(2);
    assert(a.length == 5);
    assert(a.capacity == 7); // .reserve bypasses the Growth specifier by default.
    a.reserve(1);
    a.length = 2;
    assert(a.length == 2);
    assert(a.capacity == 4);
    a.__xdtor();
    assert(a._slice is null);
    
    a = Array!int.init;
    a.put(1);
    a.put([2, 3]);
    assert(a.length == 3);
    assert(a[0] == 1);
    assert(a[1..3] == [2, 3]);
    a[1] = 4;
    assert(a[1] == 4);
    assert(a.removeAt(1) == 4);
    assert(a.length == 2);
    assert(a[1] == 3);
    a.insertAt(1, 2);
    assert(a.length == 3);
    assert(a[1] == 2);
    assert(a[2] == 3);

    int sum;
    foreach(num; a.range)
        sum += num;
    assert(sum == 6);
}