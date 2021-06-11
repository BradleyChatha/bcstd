module bcstd.meta.traits;

alias AliasSeq(T...) = T;

template allSatisfy(alias Condition, T...)
{
    bool func() 
    {
        bool result = true;

        static foreach(t; T)
        {
            static if(!Condition!t)
                result = false;    
        }
        
        return result;
    }

    enum allSatisfy = func();
}
///
@("allSatisfy")
unittest
{
    enum isIntOrString(alias T) = is(typeof(T) == int) || is(typeof(T) == string);
    static assert(allSatisfy!(isIntOrString, 0, ""));
    static assert(!allSatisfy!(isIntOrString, 0, false, ""));

    enum isIntOrStringT(T) = is(T == int) || is(T == string);
    static assert(allSatisfy!(isIntOrStringT, int, string));
    static assert(!allSatisfy!(isIntOrStringT, int, bool, string));
}

template anySatisfy(alias Condition, T...)
{
    bool func()
    {
        bool result = false;

        static foreach(t; T)
        {
            static if(Condition!t)
                result = true;
        }

        return result;
    }

    enum anySatisfy = func();
}
///
@("anySatisfy")
unittest
{
    enum isIntOrString(alias T) = is(typeof(T) == int) || is(typeof(T) == string);
    static assert(anySatisfy!(isIntOrString, 0, false));
    static assert(!anySatisfy!(isIntOrString, ['s'], false));

    enum isIntOrStringT(T) = is(T == int) || is(T == string);
    static assert(anySatisfy!(isIntOrStringT, int, bool));
    static assert(!anySatisfy!(isIntOrStringT, char[], bool));
}

template isPartOfUnion(UnionT, ValueT)
{
    bool func()
    {
        bool result;

        static foreach(name; __traits(allMembers, UnionT))
        {
            static if(is(ValueT == typeof(__traits(getMember, UnionT, name))))
                result = true;
        }

        return result;
    }

    enum isPartOfUnion = func();
}
///
@("isPartOfUnion")
unittest
{
    static union U
    {
        int a;
        string b;
    }

    static assert(isPartOfUnion!(U, int));
    static assert(isPartOfUnion!(U, string));
    static assert(!isPartOfUnion!(U, short));
    static assert(!isPartOfUnion!(U, bool));
}

enum isSomeFunction(alias F) = is(FunctionTypeOf!F _ == function);
///
@("isSomeFunction")
unittest
{
    int a;
    static void f(){}
    auto d = (){ a = 0; };

    static assert(isSomeFunction!f);
    static assert(isSomeFunction!d);
}

enum isCopyable(T) = __traits(compiles, { T t; t = T.init; });
///
@("isCopyable")
unittest
{
    struct S 
    {
        @disable this(this){}
    }

    static assert(isCopyable!int);
    static assert(!isCopyable!S);
}

enum isSlice(alias T) = is(T == E[], E);
///
@("isSlice")
unittest
{
    static assert(isSlice!(int[]));
    static assert(!isSlice!int);
}

enum isPointer(alias T) = is(T == E*, E);
///
@("isPointer")
unittest
{
    static assert(isPointer!(int*));
    static assert(!isPointer!int);
}

template ElementType(alias T)
{
    import bcstd.algorithm.common : isInputRange;

    static if(is(T == E[], E))
        alias ElementType = E;
    else static if(isInputRange!T)
        alias ElementType = typeof(T.init.front());
    else static assert(false, "Cannot determine element type of type `"~T.stringof~"`");
}
///
@("ElementType")
unittest
{
    static assert(is(ElementType!(int[]) == int));
}

template Parameters(alias F)
{
    static if(is(FunctionTypeOf!F P == function))
        alias Parameters = P;
    else
        static assert(false, F.stringof~" is not a function/delegate/there's a bug.");
}
///
@("Parameters")
unittest
{
    static void a(){}
    static void aa(int, string){}
    auto b = (){};
    auto bb = (int s, string ss){};

    static assert(is(Parameters!a == AliasSeq!()));
    static assert(is(Parameters!aa == AliasSeq!(int, string)));
    static assert(is(Parameters!b == AliasSeq!()));
    static assert(is(Parameters!bb == AliasSeq!(int, string)));
}

enum isInstanceOf(alias S, alias T) = is(T == S!Args, Args...);

template BitmaskUda(alias Uda, alias T)
{
    Uda get()
    {
        Uda value;

        static foreach(uda; __traits(getAttributes, T))
        {
            static if(__traits(compiles, typeof(uda)) && is(typeof(uda) == Uda))
                value |= uda;
        }

        return value;
    }
    enum BitmaskUda = get();
}
///
@("BitmaskUda")
unittest
{
    static enum Uda
    {
        a = 1,
        b = 2,
        c = 4
    }

    @(Uda.a, Uda.c)
    static struct A {}

    static assert(BitmaskUda!(Uda, A) == (Uda.a | Uda.c));
}

template UdaOrDefault(alias Uda, alias T, Uda default_)
{
    Uda get()
    {
        Uda value = default_;

        static if(__traits(compiles, __traits(getAttributes, T)))
        static foreach(uda; __traits(getAttributes, T))
        {
            static if(__traits(compiles, typeof(uda)) && is(typeof(uda) == Uda))
            {
                value = uda;
                goto LReturn; // Super annoying, but D *still* hates it when a conditional return is generated alongside an always-existing return.
            }
        } 

        LReturn:
        return value;
    }
    enum UdaOrDefault = get();
}
///
@("UdaOrDefault")
unittest
{
    static struct Uda {int v;}
    enum E
    {
        a,
        b
    }

    @(E.b)
    struct S{}

    static assert(UdaOrDefault!(Uda, S, Uda(200)) == Uda(200));
    static assert(UdaOrDefault!(E, S, E.a) == E.b);
}

struct TypeId
{
    string fqn;
    uint fqnHash;

    bool opEquals(const TypeId other) const @safe @nogc pure nothrow
    {
        return (this.fqnHash == other.fqnHash && this.fqn == other.fqn);
    }

    size_t toHash() const @safe @nogc pure nothrow
    {
        return this.fqnHash;
    }
}

template TypeIdOf(alias T)
{
    import bcstd.data.hash : Murmur3_32;

    const fqn = T.stringof;// TODO
    const TypeIdOf = TypeId(
        fqn,
        (){Murmur3_32 hash; hash.put(fqn); return hash.value;}()
    ); 
}
///
@("TypeIdOf")
unittest
{
    const intId = TypeIdOf!int;
    const stringId = TypeIdOf!string;

    assert(intId.fqn == "int");
    assert(intId == intId);
    assert(stringId != intId);
}

/+++++++++++++++++ STOLEN FROM PHOBOS +++++++++++++++++++/
/**
Get the function type from a callable object `func`.
Using builtin `typeof` on a property function yields the types of the
property value, not of the property function itself.  Still,
`FunctionTypeOf` is able to obtain function types of properties.
Note:
Do not confuse function types with function pointer types; function types are
usually used for compile-time reflection purposes.
 */
template FunctionTypeOf(func...)
if (func.length == 1)
{
    static if (is(typeof(& func[0]) Fsym : Fsym*) && is(Fsym == function) || is(typeof(& func[0]) Fsym == delegate))
    {
        alias FunctionTypeOf = Fsym; // HIT: (nested) function symbol
    }
    else static if (is(typeof(& func[0].opCall) Fobj == delegate))
    {
        alias FunctionTypeOf = Fobj; // HIT: callable object
    }
    else static if (is(typeof(& func[0].opCall) Ftyp : Ftyp*) && is(Ftyp == function))
    {
        alias FunctionTypeOf = Ftyp; // HIT: callable type
    }
    else static if (is(func[0] T) || is(typeof(func[0]) T))
    {
        static if (is(T == function))
            alias FunctionTypeOf = T;    // HIT: function
        else static if (is(T Fptr : Fptr*) && is(Fptr == function))
            alias FunctionTypeOf = Fptr; // HIT: function pointer
        else static if (is(T Fdlg == delegate))
            alias FunctionTypeOf = Fdlg; // HIT: delegate
        else
            static assert(0);
    }
    else
        static assert(0);
}