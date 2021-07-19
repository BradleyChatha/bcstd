module libd.threading.atomic;

nothrow @nogc pure:

private extern(C) bool atomicCas8(ubyte* ifThis, ubyte equalsThis, ubyte setThis);
private extern(C) bool atomicCas16(ushort* ifThis, ushort equalsThis, ushort setThis);
private extern(C) bool atomicCas32(uint* ifThis, uint equalsThis, uint setThis);
private extern(C) bool atomicCas64(ulong* ifThis, ulong equalsThis, ulong setThis);

private extern(C) void atomicStore8(ubyte* dest, ubyte source);
private extern(C) void atomicStore16(ushort* dest, ushort source);
private extern(C) void atomicStore32(uint* dest, uint source);
private extern(C) void atomicStore64(ulong* dest, ulong source);

private extern(C) ubyte atomicLoad8(ubyte* value);
private extern(C) ushort atomicLoad16(ushort* value);
private extern(C) uint atomicLoad32(uint* value);
private extern(C) ulong atomicLoad64(ulong* value);

@trusted
bool atomicCas(T)(shared ref T ifThis, T equalsThis, T setItToThis)
{
    static if(T.sizeof == 1)
        return atomicCas8(cast(ubyte*)&ifThis, cast(ubyte)equalsThis, cast(ubyte)setItToThis);
    else static if(T.sizeof == 2)
        return atomicCas16(cast(ushort*)&ifThis, cast(ushort)equalsThis, cast(ushort)setItToThis);
    else static if(T.sizeof == 4)
        return atomicCas32(cast(uint*)&ifThis, cast(uint)equalsThis, cast(uint)setItToThis);
    else static if(T.sizeof == 8)
        return atomicCas16(cast(ulong*)&ifThis, cast(ulong)equalsThis, cast(ulong)setItToThis);
    else
        static assert(false, "Cannot use "~T.stringof~" with CAS.");
}

@trusted
void atomicStore(T)(shared ref T intoThis, T storeThis)
{
    static if(T.sizeof == 1)
        return atomicStore8(cast(ubyte*)&intoThis, cast(ubyte)storeThis);
    else static if(T.sizeof == 2)
        return atomicStore16(cast(ushort*)&intoThis, cast(ushort)storeThis);
    else static if(T.sizeof == 4)
        return atomicStore32(cast(uint*)&intoThis, cast(uint)storeThis);
    else static if(T.sizeof == 8)
        return atomicStore16(cast(ulong*)&intoThis, cast(ulong)storeThis);
    else
        static assert(false, "Cannot use "~T.stringof~" with XCHG.");
}

@trusted
T atomicLoad(T)(shared ref T value)
{
    static if(T.sizeof == 1)
        return cast(T)atomicLoad8(cast(ubyte*)&value);
    else static if(T.sizeof == 2)
        return cast(T)atomicLoad16(cast(ushort*)&value);
    else static if(T.sizeof == 4)
        return cast(T)atomicLoad32(cast(uint*)&value);
    else static if(T.sizeof == 8)
        return cast(T)atomicLoad16(cast(ulong*)&value);
    else
        static assert(false, "Cannot use "~T.stringof~" with XCHG.");
}