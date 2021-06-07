module bcstd.datastructures.growth;

@nogc nothrow:

alias DefaultGrowth = Growth!(
    0, GrowTo!8,
    8, GrowByScale!2
);

struct Growth(Args...)
{
    import std.format : format; // Only for error messages.

    private alias GrowthFuncT = size_t function(size_t);

    // Validate that the arguments are in the correct format.
    static assert(Args.length > 0, "There must be at least 2 args.");
    static assert(Args.length % 2 == 0, "Range description args are uneven.");
    static foreach(i, arg; Args)
    {
        static if(i % 2 == 1)
        {
            // static assert(
            //     isInstanceOf!(GrowBy, typeof(arg)), 
            //     "Arg #%s is not a growth descriptor, it is a %s".format(i, typeof(arg).stringof)
            // );
        }
        else
        {
            static assert(
                __traits(compiles, { size_t a = arg; }), 
                "Arg #%s is not convertable to `size_t`".format(i)
            );

            static if(i == 0)
                static assert(arg == 0, "The first arg must always be 0.");
            else
            {
                static assert(
                    arg > Args[i-2],
                    "Arg #%s (%s) must be greater than arg #%s (%s)."
                    .format(i, arg, i-2, Args[i-2])
                );
            }
        }
    }

    static size_t grow()(size_t from)
    {
        import std.meta : Reverse;
        alias ArgsReversed = Reverse!Args;
        static foreach(i; 0..(Args.length/2)-1) // NOTE: n..-1 causes an ICE.
        {
            if(from >= ArgsReversed[(i*2)+1]) return ArgsReversed[i*2].grow(from);
        }
        return ArgsReversed[$-2].grow(from);
    }
}
///
@("Growth")
unittest
{
    alias G = Growth!(
        0,   GrowTo!64,
        64,  GrowByPercentage!2,
        128, GrowByScale!2,
        256, GrowByAmount!256
    );

    size_t value = 0;
    value = G.grow(value);
    assert(value == 64);

    value = G.grow(value);
    assert(value == 128);

    value = G.grow(value);
    assert(value == 256);

    value = G.grow(value);
    assert(value == 512);
}

struct GrowBy(alias F)
{
    static size_t grow(size_t from)
    {
        return F(from);
    }
}

auto GrowByScale(size_t scale)()
{
    return GrowBy!(from => from * scale)();
}

auto GrowByPercentage(double p)()
{
    return GrowBy!(from => cast(size_t)((cast(double)from) * p))();
}

auto GrowByAmount(size_t amount)()
{
    return GrowBy!(from => from + amount)();
}

auto GrowTo(size_t amount)()
{
    return GrowBy!(from => amount)();
}