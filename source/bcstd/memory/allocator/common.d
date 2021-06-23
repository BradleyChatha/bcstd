module bcstd.memory.allocator.common;

import bcstd.meta.ctassert : ctassert;
import bcstd.memory.ptr : MaybeNullPtr, MaybeNullSlice, NotNullSlice, maybeNull, NotNullPtr, notNull;
import bcstd.memory.funcs : emplaceCtor, dtorSliceIfNeeded, emplaceInit;
import bcstd.meta.traits : isInstanceOf, isCopyable;

enum isSimpleAllocator(alias T) =
    __traits(hasMember, T, "alloc")
 && __traits(hasMember, T, "free")
 && __traits(hasMember, T, "Tag")
 && __traits(hasMember, T, "realloc");

enum isStaticAllocator(alias T) = 
    isSimpleAllocator!T 
 && __traits(hasMember, T, "AllocIsStatic");

enum isAllocatorWrapper(alias T) = isInstanceOf!(Allocator, T);

template AllocatorWrapperOf(alias AllocOrWrapperT)
{
    static if(isAllocatorWrapper!AllocatorWrapperOf)
        alias AllocatorWrapperOf = AllocOrWrapperT;
    else
        alias AllocatorWrapperOf = Allocator!AllocOrWrapperT;
}

@nogc nothrow
struct Allocator(alias AllocT)
if(ctassert!(isSimpleAllocator!AllocT, "Type `"~AllocT.stringof~"` is not an allocator."))
{
    static assert(isAllocatorWrapper!(typeof(this)));
    static immutable string Tag = AllocT.Tag;

    alias Alloc = AllocT;
    alias isStatic = isStaticAllocator!Alloc;

    static if(isStatic)
    {
        alias instance = AllocT;

        this(_...)(_){} // To make generic code slightly easier, we'll just eat anything passed to the ctor in this case.
    }
    else
    {
        AllocT* instance;
        invariant(instance !is null, "Non-static allocator `"~AllocT.stringof~"` must be provided a solid instance before use.");

        @safe
        this(AllocT* instance)
        {
            assert(instance !is null, "Instance cannot be null.");
            this.instance = instance;
        }
    }

    @nogc nothrow:
    
    MaybeNullPtr!(T, Tag) make(T, Params...)(scope auto ref Params params)
    {
        auto slice = instance.alloc!T(1);
        if(slice is null)
            return typeof(return)(null);
        emplaceCtor(*slice.ptr, params);
        return typeof(return)(slice.ptr);
    }

    MaybeNullSlice!(T, Tag) makeArray(T, Params...)(const size_t amount, scope auto ref Params params)
    {
        auto slice = instance.alloc!T(amount);
        if(slice is null)
            return typeof(return)(null);
            
        foreach(ref item; slice)
            emplaceCtor(item, params);
        return slice;
    }

    // TODO: Check if reallocation causes the base ptr to change, and if it has, perform an internal pointer update
    //       on any types marked with `OnMove.callUpdateInternalPointers`.

    MaybeNullSlice!(T, Tag) growArray(T)(const size_t to, scope auto ref NotNullSlice!(T, Tag) slice)
    {
        if(to == slice.length)
            return slice.maybeNull;

        assert(to > slice.length, "`to` is not greater or equal to the given slice.");
        const oldLen = slice.length;
        const diff = to - slice.length;
        auto ptr = instance.realloc!T(slice, to);
        if(ptr is null)
            return typeof(return)(null);
        
        static if(!__traits(isZeroInit, T))
        {
            static if(isCopyable!T)
            {
                T init = T.init;
                ptr[oldLen..oldLen+diff] = init;
            }
            else
            {
                foreach(ref value; ptr[oldLen..oldLen+diff])
                    emplaceInit(value);
            }
        }
        return typeof(return)(ptr[0..to]);
    }

    MaybeNullSlice!(T, Tag) shrinkArray(T)(const size_t to, scope auto ref NotNullSlice!(T, Tag) slice)
    {
        if(to == slice.length)
            return slice.maybeNull;

        assert(to < slice.length, "`to` is not less than or eqaul to the given slice.");
        slice[to..$].notNull.dtorSliceIfNeeded();

        auto ptr = instance.realloc!T(slice, to);
        if(ptr is null)
            return typeof(return)(null);
        else
            return typeof(return)(ptr[0..to]);
    }

    void dispose(T)(scope auto ref NotNullPtr!(T, Tag) ptr)
    {
        static if(__traits(hasMember, T, "__xdtor"))
            ptr.ptr.__xdtor();
        instance.free!T(ptr);
    }

    void dispose(T)(scope auto ref NotNullSlice!(T, Tag) slice)
    {
        slice[0..$].notNull.dtorSliceIfNeeded();
        instance.free!T(slice);
    }

    void dispose(T)(scope auto ref T* ptr) // Trusted that the user knows what they're doing.
    {
        auto wrapped = NotNullPtr!(T, Tag)(ptr);
        this.dispose(wrapped);
        ptr = null;
    }
}