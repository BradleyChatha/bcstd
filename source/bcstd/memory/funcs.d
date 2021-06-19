module bcstd.memory.funcs;

import bcstd.memory.allocator : SystemAllocator, AllocatorWrapperOf;
import bcstd.memory.ptr;
import bcstd.meta.traits : isPointer, UdaOrDefault;

__gshared AllocatorWrapperOf!SystemAllocator g_alloc;

enum OnMove
{
    allow,
    forbid,
    callPostblit,
    callUpdateInternalPointers,
    dontDtorSource
}

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

private struct ByteSplitInfo
{
    size_t xmms;
    size_t longs;
    size_t ints;
    size_t shorts;
    size_t bytes;

    private static struct xmm
    {
        ubyte[16] _;
    }

    static ByteSplitInfo of(alias T)()
    {
        import bcstd.meta : AliasSeq;

        auto size = T.sizeof;
        ByteSplitInfo info;

        size_t result;
        
        static foreach(type; AliasSeq!(xmm, long, int, short, byte))
        {
            result = size / type.sizeof;
            if(result > 0)
            {
                mixin("info."~type.stringof~"s = result;");
                size -= type.sizeof * result;
            }
        }

        return info;
    }
    @("ByteSplitInfo.of")
    unittest
    {
        static struct S(size_t size)
        {
            ubyte[size] s;
        }

        assert(ByteSplitInfo.of!long  == ByteSplitInfo(0, 1));
        assert(ByteSplitInfo.of!int   == ByteSplitInfo(0, 0, 1));
        assert(ByteSplitInfo.of!short == ByteSplitInfo(0, 0, 0, 1));
        assert(ByteSplitInfo.of!byte  == ByteSplitInfo(0, 0, 0, 0, 1));

        assert(ByteSplitInfo.of!(S!3)  == ByteSplitInfo(0, 0, 0, 1, 1));
        assert(ByteSplitInfo.of!(S!3)  == ByteSplitInfo(0, 0, 0, 1, 1));
        assert(ByteSplitInfo.of!(S!6)  == ByteSplitInfo(0, 0, 1, 1, 0));
        assert(ByteSplitInfo.of!(S!13) == ByteSplitInfo(0, 1, 1, 0, 1));
    }
}

// This is faster than a normal byte-by-byte memcpy. It *should* be faster than the vectoirsed version LDC produces as well
// as we don't have to handle every different possible situation.
pragma(inline, true)
void memcpySmart(alias T)(scope T* source, scope T* dest)
{
    static if(!is(T == struct) || (T.sizeof <= 64 && __traits(isPOD, T)))
    {
        *dest = *source;
    }
    else
    {
        // LDC -O3 knows how to alias these properly, so no extra instructions are made.
        auto source8  = cast(ubyte*)source;
        auto source16 = cast(ushort*)source;
        auto source32 = cast(uint*)source;
        auto source64 = cast(ulong*)source;
        auto dest8    = cast(ubyte*)dest;
        auto dest16   = cast(ushort*)dest;
        auto dest32   = cast(uint*)dest;
        auto dest64   = cast(ulong*)dest;

        enum info = ByteSplitInfo.of!T;
        static foreach(i; 0..info.xmms)
        {
            static if(i == 0)
            asm @nogc nothrow pure
            {
                mov RAX, [source];
                mov RCX, [dest];
            }

            asm @nogc nothrow pure
            {
                movdqu XMM1, [RAX+i*16];
                movdqu [RCX+i*16], XMM1;
            }
        }

        enum offset64 = info.xmms * 2;
        static foreach(i; 0..info.longs)
            dest64[i+offset64] = source64[i+offset64];

        enum offset32 = info.longs * 2;
        static foreach(i; 0..info.ints)
            dest32[i+offset32] = source32[i+offset32];

        enum offset16 = offset32 + (info.ints * 2);
        static foreach(i; 0..info.shorts)
            dest16[i+offset16] = source16[i+offset16];

        enum offset8 = offset16 + (info.shorts * 2);
        static foreach(i; 0..info.bytes)
            dest8[i+offset8] = source8[i+offset8];
        return;
    }
}

@nogc nothrow
void memset(ubyte value, scope void* dest, size_t amount)
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
    memset(128, dest.ptr, 5);
    assert(dest == [128, 128, 128, 128, 128]);
}

@nogc nothrow pragma(inline, true)
void move(T, bool makeSourceInit = true, bool destroyDest = true)(scope ref T source, scope return ref T dest)
{
    enum MoveAction = UdaOrDefault!(OnMove, T, OnMove.allow);
    static assert(MoveAction != OnMove.forbid, "Type `"~T.stringof~"` explicitly forbids being moved.");

    static if(destroyDest && __traits(compiles, T.init.__xdtor()) && !isPointer!T)
        dest.__xdtor();
    memcpySmart!T(&source, &dest);

    static if(makeSourceInit)
    {
        auto init = T.init;
        memcpySmart!T(&init, &source);
    }
    
    // TODO: Apply OnMove actions for struct members as well, as members' `OnMove` udas aren't respected like this.
    static if(MoveAction == OnMove.callPostblit)
        dest.__xpostblit();
    else static if(MoveAction == OnMove.callUpdateInternalPointers)
        dest.updateInternalPointers();
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
@("move - forbid")
unittest
{
    @(OnMove.forbid)
    struct S
    {
    }

    S a, b;
    static assert(!__traits(compiles, move(a, b)));
}
@("move - callPostblit")
unittest
{
    int c;

    @(OnMove.callPostblit)
    struct S
    {
        @nogc nothrow
        this(this)
        {
            c++;
        }
    }

    S a, b;
    move(a, b);
    assert(c == 1);
}

@nogc nothrow
void emplaceCtor(T, Params...)(scope ref T dest, scope auto ref Params params)
{
    static if(is(T == struct))
        auto value = T(params);
    else static if(Params.length > 0)
        auto value = params[0];
    else
        auto value = T.init;
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