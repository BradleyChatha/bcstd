module bcstd.datastructures.string;

import core.exception : onOutOfMemoryError;
import bcstd.memory, bcstd.datastructures, bcstd.object;

version(X86_64){}
else static assert(false, "bcstd's string is only compatible on x86_64, at least for the foreseeable future.");

// For now, String will just use g_alloc because I feel having different strings with different allocators isn't actually worth it?
// If needed bcstd can provide a specialised allocator for strings.
struct String
{
    /++
        So, this abuses a few things:
            * Pointers only actually use 48-bits, with the upper 16-bits being sign extended.
            * The 47th bit is pretty much always 0 in user mode, so the upper 16-bits are also 0.
            * Little endian is an important metric for why the pointer is put last, and x86_64 is a little endian architecture.

        For 'small' strings:
            * Bits 0-22 contain the small string.
            * Bit 23 contains the null terminator (since I want bcstd's strings to always provide one without reallocation needed - cheaper integration with C libs).
            * Bit 24 contains the 'small' length, which will always be non-0 for small strings.

        For 'big' strings:
            * Bits 0-8 contain the length.
            * Bits 8-16 contain the capacity.
            * Bits 16-24 contain the allocated pointer.
                * Because of little endian, and the fact the upper 16-bits of a pointer will be 0, this sets the 'small' length to 0
                  which we can use as a flag to determine between small and big strings.

        Special case 'empty':
            If the string is completely empty, then Bits 16-24 will be all 0, indicating both that there's no 'small' length, and also a null 'big' pointer.
     + ++/
    private union Store
    {
        struct // smol
        {
            // D chars init to 0xFF (invalid utf-8 character), which we don't want here.
            // Although, because it's in a union, I don't actually know how D inits this memory by default. Better safe than sorry.
            char[22] smallString   = '\0';
            char     smallNullTerm = '\0';
            ubyte    smallLength;
        }

        struct // big
        {
            size_t bigLength;
            size_t bigCapacity;
            char*  bigPtr;
        }
    }
    private Store _store;
    static assert(typeof(this).sizeof == 24, "String isn't 24 bytes anymore :(");

    private alias _alloc = g_alloc;
    private alias Grow   = DefaultGrowth;

    @nogc nothrow:

    this(bcstring str)
    {
        this = str;
    }

    this(this)
    {
        if(!this.isCompletelyEmpty && !this.isSmall)
        {
            auto slice = this._alloc.makeArray!char(this._store.bigLength+1).slice; // We'll just allocate the length and not use Growth or capacity.
            if(slice is null)
                onOutOfMemoryError(slice.ptr);
            slice[0..$-1] = this._store.bigPtr[0..this._store.bigLength];
            slice[$-1]    = '\0';
            this._store.bigPtr      = slice.ptr;
            this._store.bigLength   = slice.length-1; // Otherwise we include the null term in this value, which we don't do.
            this._store.bigCapacity = slice.length-1; // ^^^
        }
    }

    ~this()
    {
        this.disposeBigStringIfExists();
        this._store = Store.init;
    }
    
    void put(scope bcstring chars)
    {
        auto newLength = chars.length;
        if(this.isSmall)
            newLength += this._store.smallLength;
        else
            newLength += this._store.bigLength;

        if(this.isSmall || this.isCompletelyEmpty)
        {
            if(newLength <= this._store.smallString.length)
            {
                const start = this._store.smallLength;
                this._store.smallString[start..start + chars.length] = chars[0..$];
                this._store.smallLength += chars.length;
                return;
            }

            this.moveToBigString();
        }

        this.growBigStringIfNeeded(newLength+1); // +1 for null term.
        const start = this._store.bigLength;
        this._store.bigPtr[start..start+chars.length] = chars[0..$];
        this._store.bigLength += chars.length;
        this._store.bigPtr[this._store.bigLength] = '\0';
    }

    void put(scope const ref String str)
    {
        this.put(str.sliceUnsafe);
    }

    @trusted
    bool opEquals(scope bcstring other) const
    {
        return this.sliceUnsafe == other;
    }

    @trusted
    bool opEquals()(scope auto ref const String other) const
    {
        return this.sliceUnsafe == other.sliceUnsafe;
    }

    @safe
    bool opEquals(typeof(null) _) const
    {
        return this.isCompletelyEmpty;
    }

    void opAssign(bcstring str)
    {   
        if(str is null)
            this = null;
        else if(str.length <= this._store.smallString.length)
            this.setSmallString(str);
        else
            this.setBigString(str);
    }

    void opAssign(typeof(null) _)
    {
        this.__xdtor();
    }

    @safe
    size_t opDollar() const
    {
        return this.length;
    }

    @trusted
    bcstring opIndex() const
    {
        return this.sliceUnsafe;
    }

    @trusted
    char opIndex(size_t index) const
    {
        assert(index < this.length, "Index is out of bounds.");
        return this.sliceUnsafe[index];
    }

    @trusted // Function is @safe, further usage by user is not.
    bcstring opSlice(size_t start, size_t end) const
    {
        assert(end <= this.length, "End index is out of bounds.");
        assert(start <= end, "Start index is greater than End index.");
        return this.sliceUnsafe[start..end];
    }

    @trusted // HEAVILY assumes that the allocated memory is still valid. Since at the moment we always use g_alloc, this should be guarenteed outside of bugs in this struct.
    void opIndexAssign(char v, size_t index)
    {
        assert(index < this.length, "Index is out of bounds.");
        cast()this.sliceUnsafe[index] = v; // cast away const is fine for internal functions like this.
    }

    @trusted
    void opSliceAssign(char v, size_t start, size_t end)
    {
        auto slice = cast(char[])this[start..end];
        slice[] = v;
    }

    @trusted
    void opSliceAssign(bcstring str, size_t start, size_t end)
    {
        auto slice = cast(char[])this[start..end];
        assert(end - start == str.length, "Mismatch between str.length, and (end - start).");
        slice[0..$] = str[0..$];
    }

    @trusted
    String opBinary(string op)(const scope auto ref String rhs) const
    if(op == "~")
    {
        String ret = cast()this; // NRVO better come into play here.
        ret.put(rhs);
        return ret;
    }

    @trusted
    String opBinary(string op)(scope bcstring rhs) const
    if(op == "~")
    {
        String ret = cast()this; // NRVO better come into play here.
        ret.put(rhs);
        return ret;
    }

    @trusted
    void opOpAssign(string op)(const scope auto ref String rhs)
    if(op == "~")
    {
        this.put(rhs);
    }

    @trusted
    void opOpAssign(string op)(scope bcstring rhs)
    if(op == "~")
    {
        this.put(rhs);
    }

    alias range = rangeUnsafe; // Could probably make a safe/safer custom range in the future.
    @property
    bcstring rangeUnsafe() const
    {
        return this.sliceUnsafe;
    }

    @property @safe
    size_t length() const
    {
        return (this.isSmall) ? this._store.smallLength : this._store.bigLength; 
    }

    @property
    void length(size_t newLen)
    {
        if(this.isSmall || this.isCompletelyEmpty)
        {
            if(newLen > this._store.smallString.length)
            {
                this.moveToBigString();
                this.length = newLen; // So we don't have to duplicate logic.
            }
            else
                this._store.smallLength = cast(ubyte)newLen;
            return;
        }

        // Lazy choice: Once we're a big string, we're always a big string.
        //              Will eventually *not* do this, but >x3
        if(newLen > this._store.bigLength)
        {
            const start = this._store.bigLength;
            this.growBigStringIfNeeded(newLen);
            this._store.bigPtr[start..newLen] = char.init;
        }

        this._store.bigLength = newLen;
        this._store.bigPtr[newLen] = '\0';
    }

    @property
    const(char)* ptrUnsafe() const return
    {
        return (this.isSmall) ? &this._store.smallString[0] : this._store.bigPtr;
    }

    @property
    bcstring sliceUnsafe() const return
    {
        return (this.isSmall) ? this._store.smallString[0..this._store.smallLength] : this._store.bigPtr[0..this._store.bigLength];
    }

    private void setSmallString(scope bcstring chars)
    {
        assert(chars.length <= this._store.smallString.length);
        this.disposeBigStringIfExists(); // Resets us to a "completely empty" state.
        this._store.smallString[0..chars.length] = chars[0..$];
        this._store.smallLength = cast(ubyte)chars.length;
    }

    private void setBigString(scope bcstring chars)
    {
        this.growBigStringIfNeeded(chars.length+1); // +1 for null term.
        assert(this._store.smallLength == 0, "Nani?");
        this._store.bigLength               = chars.length;
        this._store.bigPtr[0..chars.length] = chars[0..$];
        this._store.bigPtr[chars.length]    = '\0';
        assert(!this.isSmall, "Eh?");
    }

    private void moveToBigString()
    {
        if(this.isCompletelyEmpty || !this.isSmall)
            return;

        // Have to copy into a buffer first, otherwise setBigString will overwrite the string data before it ends up copying it.
        char[22] buffer;
        buffer[0..$]      = this._store.smallString[0..$];
        const smallLength = this._store.smallLength;
        this.setBigString(buffer[0..smallLength]);
    }

    private void growBigStringIfNeeded(size_t newSize)
    {
        if(this.isCompletelyEmpty || this.isSmall)
        {
            this._store.bigCapacity = Grow.grow(newSize);
            this._store.bigPtr      = this._alloc.makeArray!char(this._store.bigCapacity).ptr;
            if(this._store.bigPtr is null)
                onOutOfMemoryError(null);
            return;
        }

        if(newSize > this._store.bigCapacity)
        {
            const oldCapacity       = this._store.bigCapacity;
            this._store.bigCapacity = Grow.grow(newSize);
            this._store.bigPtr      = this._alloc.growArray!char(
                this._store.bigCapacity, 
                this._store.bigPtr[0..oldCapacity].notNull!(_alloc.Tag)
            ).ptr;
            if(this._store.bigPtr is null)
                onOutOfMemoryError(null);
        }
    }

    private void disposeBigStringIfExists()
    {
        if(!this.isCompletelyEmpty && !this.isSmall)
        {
            this._alloc.dispose(this._store.bigPtr); // set to null by .dispose
            this._store.smallString[] = '\0';
            this._store.smallNullTerm = '\0';
            assert(this.isCompletelyEmpty, "?");
        }
    }

    @trusted
    private bool isCompletelyEmpty() const
    {
        return this._store.bigPtr is null;
    }

    @safe
    private bool isSmall() const
    {
        return this._store.smallLength > 0;
    }
}
///
@("String")
unittest
{
    auto s = String("Hello");
    assert(s.isSmall); // .isSmall is a private function
    assert(!s.isCompletelyEmpty); // ^^^
    assert(s.length == 5);
    assert(s == "Hello");
    assert(s.ptrUnsafe[5] == '\0');

    auto s2 = s;
    assert(s2.isSmall && !s2.isCompletelyEmpty);
    assert(s2.length == 5);
    assert(s2 == "Hello");
    s2.put(", world!");
    assert(s2.length == 13);
    assert(s.length == 5);
    assert(s2 == "Hello, world!");
    assert(s2.ptrUnsafe[13] == '\0');

    s = String("This is a big string that is bigger than 22 characters long!");
    assert(!s.isSmall);
    assert(s.length == 60);
    assert(s == "This is a big string that is bigger than 22 characters long!");
    assert(s.ptrUnsafe[60] == '\0');

    s2 = s;
    assert(!s2.isSmall);
    assert(s2.length == 60);
    assert(s2._store.bigPtr !is s._store.bigPtr);
    s.__xdtor();
    s2.put("This shouldn't crash because we copied things.");
    assert(s2 == "This is a big string that is bigger than 22 characters long!This shouldn't crash because we copied things.");
    assert(s2.ptrUnsafe[s2.length] == '\0');

    s2.length = 60;
    assert(s2.length == 60);
    assert(s2 == "This is a big string that is bigger than 22 characters long!");
    assert(s2.ptrUnsafe[60] == '\0');

    s2.length = 61;
    assert(s2 == "This is a big string that is bigger than 22 characters long!"~char.init);
    assert(s2.ptrUnsafe[61] == '\0');

    // Making sure we don't crash when using any of these things from a .init state.
    s2.__xdtor();
    assert(!s2.isSmall && s2.isCompletelyEmpty);
    assert(s2.ptrUnsafe is null);
    assert(s2.sliceUnsafe is null);
    assert(s2.length == 0);
    s2.put("abc");
    assert(s2.isSmall);

    assert(s2 == "abc");
    assert(s2 == String("abc"));
    assert(s2 != null);
    s2 = null;
    assert(s2 == null);

    s2 = "abc";
    assert(s2.isSmall);
    assert(s2 == "abc");
    assert(s2[1] == 'b');
    assert(s2[0..2] == "ab");
    assert(s2[3..3].length == 0);
    assert(s2[] == "abc");

    s2[1] = 'd';
    assert(s2 == "adc");
    s2[0..2] = 'b';
    assert(s2 == "bbc");
    s2[0..3] = "put";
    assert(s2 == "put");

    assert(s2 ~ "in" == "putin");
    assert(s2 ~ String("ty") == "putty");
    s2 ~= " it ";
    assert(s2 == "put it ");
    s2 ~= String("in mah belleh");
    assert(s2 == "put it in mah belleh");
}