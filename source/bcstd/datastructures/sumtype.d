module bcstd.datastructures.sumtype;

import bcstd.meta : assertIsPartOfUnion, assertAllSatisfy, Parameters, isSomeFunction;

@nogc nothrow
struct SumType(UnionT)
{
    alias Union = UnionT;

    // Can't static foreach inside an enum, so this is the next best thing?
    // It really. REALLY sucks that you get -betterC limitations inside of CTFE-only funcs.
    struct Kind
    {
        private int i;
        static foreach(i2, name; __traits(allMembers, UnionT))
            mixin("static immutable Kind "~name~" = Kind(i2+1);");

        @safe @nogc
        private bool isUnassigned() nothrow const
        {
            return this.i == 0;
        }

        @safe @nogc
        size_t index() nothrow const
        {
            return this.i;
        }
    }

    @nogc nothrow:

    private Kind   _kind;
    private UnionT _value;

    this(T)(auto ref T value)
    {
        this.set(value);
    }

    this(this)
    {
        if(this._kind.isUnassigned)
            return;

        switch(this._kind.i)
        {
            static foreach(member; __traits(allMembers, UnionT))
            {{
                alias Type = typeof(__traits(getMember, UnionT, member));
                case typeof(this).kindOf!Type.i:
                    static if(__traits(compiles, Type.init.__xpostblit()))
                        this.get!Type.__xpostblit();
                    return;
            }}

            default: assert(false, "??");
        }
    }

    ~this()
    {
        this.dtorValue();
    }

    static Kind kindOf(T)()
    if(assertIsPartOfUnion!(UnionT, T))
    {
        static foreach(member; __traits(allMembers, UnionT))
        {
            static if(is(T == typeof(__traits(getMember, UnionT, member))))
                mixin("return Kind."~member~";");
        }
        assert(false, "assertIsPartOfUnion should've triggered.");
    }

    void set(T)(auto ref T value)
    if(assertIsPartOfUnion!(UnionT, T))
    {
        enum NewKind = typeof(this).kindOf!T;
        this.dtorValue();
        this._kind = NewKind;

        static foreach(member; __traits(allMembers, UnionT))
        {{
            alias Type = typeof(__traits(getMember, UnionT, member));
            static if(is(Type == T))
                mixin("this._value."~member~" = value;");
        }}
    }

    ref T get(T)()
    if(assertIsPartOfUnion!(UnionT, T))
    {
        static foreach(member; __traits(allMembers, UnionT))
        {{
            alias Type = typeof(__traits(getMember, UnionT, member));
            static if(is(Type == T))
            {
                assert(this._kind == typeof(this).kindOf!T,
                    "This SumType holds a value of type `"~"(TODO)"~"`, but a value of`"
                  ~ T.stringof~"` was asked for."
                );
                mixin("return this._value."~member~";");
            }
        }}
    }

    bool contains(T)()
    {
        return this._kind == typeof(this).kindOf!T;
    }

    void opAssign(T)(auto ref T value)
    if(!is(T == typeof(this)))
    {
        this.set(value);
    }

    alias visit(Handlers...) = _visit!(typeof(this), Handlers);

    @property @safe @nogc
    Kind kind() nothrow const
    {
        return this._kind;
    }

    private void dtorValue()()
    {
        if(this._kind.isUnassigned)
            return;

        auto kind = this._kind;
        this._kind = Kind(0);

        switch(kind.i)
        {
            static foreach(member; __traits(allMembers, UnionT))
            {{
                alias Type = typeof(__traits(getMember, UnionT, member));
                enum TypeKind = typeof(this).kindOf!Type;

                case TypeKind.i:
                    static if(__traits(compiles, Type.init.__xdtor()))
                        mixin("this._value."~member~".__xdtor();");
                    this._value = UnionT.init;
                    return;
            }}

            default: assert(false, "Unknown Kind ID, wut?");
        }
    }
}
///
@("SumType")
unittest
{
    union U
    {
        int a;
        string b;
        Object c;
    }

    alias Sum = SumType!U;

    static assert(Sum.kindOf!int    == Sum.Kind.a);
    static assert(Sum.kindOf!Object == Sum.Kind.c);

    auto value = Sum(20);
    assert(value.kind == Sum.Kind.a && value.kind == Sum.kindOf!int);
    assert(value.contains!int);

    bool threw = false;
    try value.get!string();
    catch(Error error)
        threw = true;
    assert(threw);

    assert(value.get!int == 20);
    value = "lol";
    assert(value.kind == Sum.Kind.b && value.kind == Sum.kindOf!string);
    assert(value.contains!string);
    assert(value.get!string == "lol");

    int unhandled;
    void visitTest(ref Sum sum)
    {
        sum.visit!(
            (ref int i) { i *= 2; },
            (ref string b) { b ~= "lol"; },
            () { unhandled++; }
        )(sum);
    }
    
    value = 20;
    visitTest(value);
    assert(value.get!int == 40);

    value = "lol";
    visitTest(value);
    assert(value.get!string == "lollol");

    value = new Object();
    visitTest(value);
    assert(unhandled == 1);
}

@("SumType - PostBlit")
unittest
{
    auto dtor = 0;
    auto pblit = 0;

    static struct S
    {
        int* dtor;
        int* pblit;

        @nogc nothrow:

        this(this)
        {
            if(this.pblit)
                (*this.pblit)++;
        }

        ~this()
        {
            if(this.dtor)
                (*this.dtor)++;
        }
    }

    static union U
    {
        S s;
        int _;
    }

    alias Sum = SumType!U;

    auto s = S(&dtor, &pblit);
    assert(dtor == 0 && pblit == 0);

    auto sum = Sum(s);
    assert(pblit == 1);
    assert(dtor == 0);

    sum = 0;
    assert(pblit == 1);
    assert(dtor == 1);

    sum = 1;
    assert(pblit == 1);
    assert(dtor == 1);

    sum.__xdtor();
    assert(pblit == 1);
    assert(dtor == 1);

    sum = s;
    assert(pblit == 2);
    assert(dtor == 1);

    auto sum2 = sum;
    assert(pblit == 3);
    assert(dtor == 1);

    sum.__xdtor();
    sum.__xdtor();
    sum2.__xdtor();
    sum2.__xdtor();
    assert(pblit == 3);
    assert(dtor == 3);
}

private void _visit(SumT, Handlers...)(ref SumT sum)
if(assertAllSatisfy!(isSomeFunction, Handlers))
{
    bool handled = false;
    scope(exit) assert(handled, "No handler was provided for the type held within this SumType, and no default handler was provided.");
    static foreach(handler; Handlers)
    {{
        alias Params = Parameters!handler;
        static if(Params.length == 0)
        {
            scope(exit)
            {
                if(!handled)
                {
                    handled = true;
                    handler();
                }
            }
        }
        else
        {
            if(sum._kind.i == SumT.kindOf!(Params[0]).i)
            {
                handler(sum.get!(Params[0]));
                handled = true;
                return;
            }
        }
    }}
}