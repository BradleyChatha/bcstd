module bcstd.memory.funcs;

import bcstd.memory.allocator : SystemAllocator, AllocatorWrapperOf;
import bcstd.memory.ptr;
import bcstd.meta.traits : isPointer; 

@live:

__gshared AllocatorWrapperOf!SystemAllocator g_alloc;

@nogc nothrow
void memcpy(scope const void* source, scope void* dest, size_t bytes)
{
    auto sourceBytes = cast(const ubyte*)source;
    auto destBytes = cast(ubyte*)dest;

    // LDC knows how to auto-vectorise this.
    // Shock horror, DMD can't though.
    // Even worse, if we write it slightly differently, it calls the C lib's memcpy, which defeats the point of this hobby project xP
    for(size_t i = 0; i < bytes; i++)
        destBytes[i] = sourceBytes[i];
}
///
@("memcpy")
unittest
{
    const ubyte[5] source = [1, 2, 3, 4, 5];
    ubyte[5] dest;
    memcpy(source.ptr, &dest[0], 5);
    assert(dest[] == source);
}

@nogc nothrow
void memset(scope void* dest, ubyte value, size_t amount)
{
    auto destBytes = cast(ubyte*)dest;
    for(size_t i = 0; i < amount; i++)
        destBytes[i] = value;
}
///
@("memset")
unittest
{
    ubyte[5] dest;
    memset(dest.ptr, 128, 5);
    assert(dest == [128, 128, 128, 128, 128]);
}

@nogc nothrow
void move(T, bool makeSourceInit = true)(scope ref T source, scope ref T dest)
{
    static if(__traits(compiles, T.init.__xdtor()) && !isPointer!T)
        dest.__xdtor();
    memcpy(&source, &dest, T.sizeof);

    static if(makeSourceInit)
    {
        auto init = T.init;
        memcpy(&init, &source, T.sizeof);
    }
}
///
@("move")
unittest
{
    int postblitCount;
    int dtorCount;
    struct S
    {
        @nogc nothrow:
        int value;
        this(this){ postblitCount++; }
        ~this(){ if(value > 0) dtorCount++; }
    }

    S a = S(20);
    S b = S(40);

    assert(postblitCount == 0 && dtorCount == 0);
    move(a, b);
    assert(dtorCount == 1);
    assert(postblitCount == 0);
    assert(a == S.init);
    assert(b.value == 20);
}
@("move - !isCopyable")
unittest
{
    struct S
    {
        @nogc nothrow:
        int value;
        @disable this(this){}
    }

    S a = S(20);
    S b = S(40);
    move(a, b);

    assert(a == S.init);
    assert(b.value == 20);
}

@nogc nothrow
void emplaceCtor(T, Params...)(scope ref T dest, scope auto ref Params params)
{
    auto value = T(params);
    move(value, dest);
}
@("emplaceCtor")
unittest
{
    static struct S
    {
        @nogc nothrow:
        int value;
        @disable this(this){}
    }

    S a;
    emplaceCtor(a, 20);
    assert(a.value == 20);
}

@nogc nothrow
void emplaceInit(T)(scope ref T dest)
{
    auto value = T.init;
    move!(T, false)(value, dest);
}
@("emplaceInit")
unittest
{
    static struct S
    {
        int value = 100;
        @disable this(this){}
    }
    
    S a = S(200);
    emplaceInit(a);
    assert(a.value == 100);
}

@nogc nothrow
void dtorSliceIfNeeded(T)(scope NotNullSlice!T slice)
{
    static if(__traits(hasMember, T, "__xdtor"))
    {
        foreach(ref item; slice[0..$])
            item.__xdtor();
    }
}
@("dtorSliceIfNeeded")
unittest
{
    int dtor = 0;
    static struct S
    {
        int* dtor;
        @disable this(this){}
        ~this() @nogc nothrow
        {
            if(dtor) (*dtor)++;
        }
    }

    auto array = [S(&dtor), S(&dtor)];
    array.notNull.dtorSliceIfNeeded();
    assert(dtor == 2);
    array[] = S.init;
}