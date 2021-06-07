module bcstd.memory.ptr;

// "NotNull" is deemed "uninitialised" if it's value is null. Think of it like "undefined" from JS.

struct NotNullPtr(T, string Tag_ = "default")
{
    static immutable Tag = Tag_;
    alias ptr this;
    T* ptr;

    auto opAssign()(T* ptr)
    {
        assert(ptr !is null, "Pointer is null.");
        this.ptr = ptr;
        return this;
    }

    auto opAssign()(MaybeNullPtr!(T, Tag) ptr)
    {
        assert(ptr !is null, "Pointer is null.");
        this.ptr = ptr;
        return this;
    }

    auto opAssign(string Tag2)(MaybeNullPtr!(T, Tag2) ptr)
    if(Tag2 != Tag)
    {
        static assert(false, "Cannot implicitly assign from pointer with different tag.");
    }
}

struct MaybeNullPtr(T, string Tag_ = "default")
{
    static immutable Tag = Tag_;
    alias ptr this;
    T* ptr;
}

struct NotNullSlice(T, string Tag_ = "default")
{
    static immutable Tag = Tag_;
    alias slice this;
    T[] slice;

    auto opAssign()(T[] value)
    {
        assert(value !is null, "Slice is null.");
        this.slice = value;
        return this;
    }

    auto opAssign()(MaybeNullSlice!(T, Tag) slice)
    {
        assert(slice !is null, "Slice is null.");
        this.slice = slice.slice;
        return this;
    }

    auto opAssign(string Tag2)(MaybeNullSlice!(T, Tag2) slice)
    if(Tag2 != Tag)
    {
        static assert(false, "Cannot implicitly assign from slice with different tag.");
    }
}

struct MaybeNullSlice(T, string Tag_ = "default")
{
    static immutable Tag = Tag_;
    alias slice this;
    T[] slice;
}

@safe @nogc nothrow pure:
// This code is mostly write-once update-never due to its simple nature, so I don't give a damn about making it readable.
MaybeNullPtr  !(T, Tag) maybeNull(string Tag, T)(T* ptr)    { return typeof(return)(ptr);   }
MaybeNullPtr  !(T, Tag) maybeNull(string Tag, T)(NotNullPtr!(T, Tag) ptr) { return typeof(return)(ptr); }
MaybeNullSlice!(T, Tag) maybeNull(string Tag, T)(T[] slice) { return typeof(return)(slice); }
MaybeNullSlice!(T, Tag) maybeNull(string Tag, T)(NotNullSlice!(T, Tag) slice) { return typeof(return)(slice); }
NotNullPtr    !(T, Tag) notNull  (string Tag, T)(T* ptr)    { assert(ptr !is null, "Pointer is null"); return typeof(return)(ptr); }
NotNullPtr    !(T, Tag) notNull  (string Tag, T)(MaybeNullPtr!(T, Tag) ptr) { assert(ptr !is null, "Pointer is null"); return typeof(return)(ptr); }
NotNullSlice  !(T, Tag) notNull  (string Tag, T)(T[] slice) { assert(slice !is null, "Slice is null"); return typeof(return)(slice); }
NotNullSlice  !(T, Tag) notNull  (string Tag, T)(MaybeNullSlice!(T, Tag) slice) { assert(slice !is null, "Slice is null"); return typeof(return)(slice); }

MaybeNullPtr  !(T, "default") maybeNull(T)(T* ptr)    { return typeof(return)(ptr);   }
NotNullPtr    !(T, "default") notNull  (T)(T* ptr)    { assert(ptr !is null, "Pointer is null"); return typeof(return)(ptr); }
MaybeNullSlice!(T, "default") maybeNull(T)(T[] slice) { return typeof(return)(slice); }
NotNullSlice  !(T, "default") notNull  (T)(T[] slice) { assert(slice !is null, "Slice is null"); return typeof(return)(slice); }