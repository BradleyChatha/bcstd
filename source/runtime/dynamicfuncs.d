module runtime.dynamicfuncs;

// Functions that are dynamically selected at runtime, depending on the CPU.

private alias memequalT = extern(C) bool function(const scope void* a, const scope void* b, size_t amount) @nogc nothrow;

__gshared memequalT memequal;

void _d_dynamicFuncsInit()
{
    selectMemequal();

    assert(memequal !is null);
}

private:

void selectMemequal()
{
    memequal = &memequalSlow;
}

@nogc nothrow
extern(C) bool memequalSlow(const scope void* a, const scope void* b, size_t amount)
{
    auto aBytes = cast(ubyte*)a;
    auto bBytes = cast(ubyte*)b;

    foreach(_; 0..amount)
    {
        if(*aBytes != *bBytes)
            return false;
        aBytes++;
        bBytes++;
    }

    return true;
}