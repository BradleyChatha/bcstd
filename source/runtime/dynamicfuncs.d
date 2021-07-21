module runtime.dynamicfuncs;

// Functions that are dynamically selected at runtime, depending on the CPU.

private alias memequalT = extern(C) bool function(const scope void* a, const scope void* b, size_t amount) @nogc nothrow;
private alias strlenT = extern(C) size_t function(const scope char* str) @nogc nothrow;

__gshared memequalT memequal;
__gshared strlenT strlen;

void _d_dynamicFuncsInit()
{
    select();

    assert(memequal !is null);
}

private:

void select()
{
    memequal = &memequalSlow;
    strlen = &strlenSlow;
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

@nogc nothrow
extern(C) size_t strlenSlow(const scope char* str)
{
    if(str is null)
        return 0;

    const start = str;
    auto strMut = cast(char*)str;
    while(*strMut != '\0')
        strMut++;
    return cast(size_t)(strMut - start);
}