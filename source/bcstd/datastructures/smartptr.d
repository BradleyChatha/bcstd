module bcstd.datastructures.smartptr;

import bcstd.algorithm : any;
import bcstd.memory : move, emplaceInit, AllocatorWrapperOf, SystemAllocator, maybeNull;
import bcstd.meta : TypeId, TypeIdOf, isCopyable;

private mixin template accessFuncs(bool TypeHasT)
{
    static if(TypeHasT)
    {
        void access()(scope void delegate(T) @nogc nothrow func)
        {
            static assert(false, "Please mark the parameter as `scope ref`");
        }

        void access()(scope void function(T) @nogc nothrow func)
        {
            static assert(false, "Please mark the parameter as `scope ref`");
        }

        void access(scope void delegate(scope ref T) @nogc nothrow func) { this.accessImpl(func); }
        void access(scope void function(scope ref T) @nogc nothrow func) { this.accessImpl(func); }
        @safe
        void access(scope void delegate(scope ref T) @nogc @safe nothrow func) { this.accessImpl(func); }
        @safe
        void access(scope void function(scope ref T) @nogc @safe nothrow func) { this.accessImpl(func); }
    }
    else
    {
        void access(T)(scope void delegate(T) @nogc nothrow func)
        {
            static assert(false, "Please mark the parameter as `scope ref`");
        }

        void access(T)(scope void function(T) @nogc nothrow func)
        {
            static assert(false, "Please mark the parameter as `scope ref`");
        }

        void access(T)(scope void delegate(scope ref T) @nogc nothrow func) { this.accessImpl!T(func); }
        void access(T)(scope void function(scope ref T) @nogc nothrow func) { this.accessImpl!T(func); }
        @safe
        void access(T)(scope void delegate(scope ref T) @nogc @safe nothrow func) { this.accessImpl!T(func); }
        @safe
        void access(T)(scope void function(scope ref T) @nogc @safe nothrow func) { this.accessImpl!T(func); }
    }
}

struct Unique(alias T)
{
    private T    _value;
    private bool _set;

    @disable this(this){}

    @nogc nothrow:

    this()(auto ref T value)
    {
        this = value;
    }

    this(scope ref return typeof(this) rhs)
    {
        move(rhs._value, this._value);
        this._set = true;
        rhs._set = false;
    }

    private void accessImpl(T)(T func)
    {
        assert(!this.isNull, "This Unique is null");
        func(this._value);
    }

    mixin accessFuncs!true;

    void opAssign()(auto ref T value)
    {
        move(value, this._value);
        this._set = true;
    }

    void opAssign()(typeof(null) n)
    {
        emplaceInit(this._value);
        this._set = false;
    }

    void release()(scope ref return T dest)
    {
        move(this._value, dest);
        this._set = false;
    }

    void release()(scope ref return typeof(this) dest)
    {
        move(this._value, dest._value);
        this._set = false;
        dest._set = true;
    }

    typeof(this) release()
    {
        typeof(this) ret;
        this.release(ret);
        return ret; // NRVO makes this possible for non-copyable types.
    }

    T releaseRaw()()
    {
        T ret;
        move(this._value, ret);
        this._set = false;
        return ret;
    }

    @property @safe
    bool isNull() const
    {
        return !this._set;
    }

    @property
    inout(T)* ptrUnsafe() inout
    {
        assert(!this.isNull, "This Unique is null.");
        return &this._value;
    }
}
///
@("Unique")
unittest
{
    int dtor = 0;
    static struct S
    {
        int num;
        int* dtor;
        @disable this(this){}
        @nogc nothrow ~this()
        {
            if(dtor)
                (*dtor)++;
        }
    }

    S s = S(200, &dtor);
    Unique!S a = s;
    Unique!S b;

    assert(s == S.init);
    assert(!a.isNull);
    assert(b.isNull);
    assert(a.ptrUnsafe.num == 200);
    a.access((scope ref v)
    {
        assert(v.num == 200);
        v.num *= 2;
    });

    move(a, b);
    assert(a.isNull);
    assert(a._value == S.init);
    assert(!b.isNull);
    assert(b.ptrUnsafe.num == 400);

    a = Unique!S(S(800, &dtor));
    assert(!a.isNull);
    assert(a.ptrUnsafe.num == 800);
    a = null;
    assert(a.isNull);
    assert(a._value == S.init);
    assert(dtor == 1);

    b.release(s);
    assert(b.isNull);
    assert(s.num == 400);

    a = s;
    a.release(b);
    assert(a.isNull);
    assert(!b.isNull);

    void test(Unique!S s)
    {
        assert(!s.isNull);
        auto ss = s.releaseRaw();
        assert(s.isNull);
        assert(ss.num == 400);
    }

    test(b.release);
    assert(dtor == 2);

    Unique!S test2(Unique!S s)
    {
        assert(!s.isNull);
        return s.release;
    }

    a = S(200, &dtor);
    b = test2(a.release);
    assert(dtor == 2);
    assert(a.isNull);
    assert(!b.isNull);
    b.__xdtor();
    assert(dtor == 3);
}

Unique!T makeUnique(T)(auto ref T value)
{
    return typeof(return)(value);
}

struct Shared(alias T, alias AllocT = SystemAllocator)
{
    private static struct Store
    {
        T value;
        ulong count;
    } 

    private Store* _store;
    private AllocatorWrapperOf!AllocT _alloc;

    @nogc nothrow:

    @safe
    this(AllocatorWrapperOf!AllocT alloc)
    {
        this._alloc = alloc;
    }

    this()(auto ref T value, AllocatorWrapperOf!AllocT alloc = AllocatorWrapperOf!AllocT.init)
    {
        this._alloc = alloc;
        this.createNewStore(value);
    }

    this(scope ref return typeof(this) copy)
    {
        auto oldStore = this._store;

        this._store = copy._store;
        this._alloc = copy._alloc;
        if(this._store !is null)
            this.refUp();
        if(oldStore !is null)
            this.refDown();
    }

    private void accessImpl(T)(T func)
    {
        assert(!this.isNull, "This Shared is null.");
        func(this._store.value);
    }

    mixin accessFuncs!true;

    ~this()
    {
        if(!this.isNull)
            this.refDown();
    }

    void createNewStore()(auto ref T value)
    {
        if(this._store !is null)
            this.refDown();
        this._store = this._alloc.make!Store();
        if(this._store is null)
            assert(false, "Memory allocation failed.");
        move(value, this._store.value);
        this.refUp();
    }

    void opAssign()(typeof(null) n)
    {
        if(this._store !is null)
            this.refDown();
        this._store = null;
    }

    @property @safe
    bool isNull() const
    {
        return this._store is null;
    }

    @property
    inout(T)* ptrUnsafe() inout
    {
        assert(!this.isNull, "This Shared is null.");
        return &this._store.value;
    }

    @safe
    private void refUp()
    {
        this._store.count++;
    }

    private void refDown()()
    {
        this._store.count--;
        if(this._store.count == 0)
        {
            this._alloc.dispose(this._store.maybeNull!(AllocT.Tag));
            this._store = null;
        }
    }
}
///
@("Shared")
unittest
{
    int dtor;
    static struct S
    {
        int value;
        int* dtor;
        @disable this(this);

        ~this() @nogc nothrow
        {
            if(dtor)
                (*dtor)++;
        }
    }

    // Simple
    {
        auto a = S(200, &dtor).makeShared;
    }
    assert(dtor == 1);
    dtor = 0;

    // Copying
    {
        auto a = S(200, &dtor).makeShared;
        auto b = a;
    }
    assert(dtor == 1);
    dtor = 0;

    // Copying over existing
    {
        auto a = S(200, &dtor).makeShared;
        auto b = S(400, &dtor).makeShared;
        b = a;
    }
    assert(dtor == 2);
    dtor = 0;

    // Null assign
    {
        auto a = S(200, &dtor).makeShared;
        a = null;
        assert(dtor == 1);
    }

    // Access
    {
        auto a = S(200, &dtor).makeShared;
        auto b = a;

        b.access((scope ref v)
        {
            v.value *= 2;
        });
        assert(a.ptrUnsafe.value == b.ptrUnsafe.value);
        assert(a.ptrUnsafe.value == 400);
    }
}

Shared!(T, AllocT) makeShared(T, alias AllocT = SystemAllocator)(auto ref T value, AllocatorWrapperOf!AllocT alloc = AllocatorWrapperOf!AllocT.init)
{
    return typeof(return)(value, alloc);
}

struct TypedPtrBase(alias AllocT = SystemAllocator)
{
    private void*  _ptr;
    private TypeId _id;
    private AllocatorWrapperOf!AllocT _alloc;

    @disable this(this){}

    @nogc nothrow:

    this(AllocatorWrapperOf!AllocT alloc)
    {
        this._alloc = alloc;
    }

    this(T)(auto ref T value, AllocatorWrapperOf!AllocT alloc = AllocatorWrapperOf!AllocT.init)
    {
        this._alloc = alloc;
        this.setByForce(value);
    }

    ~this()
    {
        if(this._ptr !is null)
            this._alloc.dispose(this._ptr.maybeNull!(AllocT.Tag));
    }

    @trusted // Because ptrUnsafeAs is not @safe. It technically *is* @safe by itself due to the safety checks, but the user can use it to perform @system behaviour.
    private void accessImpl(ValueT, FuncT)(FuncT func)
    {
        assert(!this.isNull, "This TypedPtr is null.");
        func(*this.ptrUnsafeAs!ValueT);
    }

    mixin accessFuncs!false;

    @safe
    bool contains(alias T)() const
    {
        assert(!this.isNull, "This TypedPtr is null.");
        return this._id == TypeIdOf!T;
    }

    void setByForce(T)(auto ref T value)
    {
        static if(is(T == struct))
            static assert(__traits(isPOD, T), "Type `"~T.stringof~"` must be a POD struct.");

        if(this._ptr is null)
        {
            this._ptr = this._alloc.make!T();
            if(this._ptr is null)
                assert(false, "Memory allocation failed.");
        }
        else if(this._id != TypeIdOf!value)
        {
            this._alloc.dispose(this._ptr.maybeNull!(AllocT.Tag));
            this._ptr = null;
            this.setByForce(value);
            return;
        }

        move(value, *(cast(T*)this._ptr));
        this._id = TypeIdOf!T;
    }

    void opAssign(T)(auto ref T value)
    {
        assert(
            this.isNull || this._id == TypeIdOf!T, 
            "opAssign cannot store a value of a different type from the current value. Use `setByForce` for that."
        );
        this.setByForce(value);
    }

    void opAssign()(typeof(null) n)
    {
        if(!this.isNull)
        {
            this._id = TypeId.init;
            this._alloc.dispose(this._ptr);
        }
    }

    @property @safe
    bool isNull() const
    {
        return this._ptr is null;
    }

    @property
    inout(void*) ptrUnsafe() inout
    {
        assert(!this.isNull, "This TypedPtr is null.");
        return this._ptr;
    }

    @property
    inout(T)* ptrUnsafeAs(T)() inout
    {
        assert(!this.isNull, "This TypePtr is null.");
        assert(this._id == TypeIdOf!T, "Type mismatch. This TypedPtr does not store `"~T.stringof~"`");
        return cast(inout(T)*)this._ptr;
    }
}
alias TypedPtr = TypedPtrBase!();
///
@("TypedPtr")
unittest
{
    static struct S
    {
        int value;
    }
    
    auto ptr = S(200).makeTyped;
    assert(!ptr.isNull);
    assert(ptr.contains!S);
    assert(ptr.ptrUnsafeAs!S.value == 200);
    ptr.access!S((scope ref s)
    {
        s.value *= 2;
    });
    assert(ptr.ptrUnsafeAs!S.value == 400);
    ptr = S(100);
    assert(ptr.ptrUnsafeAs!S.value == 100);
    
    // opAssign cannot change types.
    bool threw = false;
    try ptr = 200;
    catch(Error error)
        threw = true;
    assert(threw);

    // But setForce can
    ptr.setByForce(200);
    assert(ptr.contains!int);
    assert(*ptr.ptrUnsafeAs!int == 200);

    ptr = null;
    assert(ptr.isNull);
}

TypedPtrBase!AllocT makeTyped(T, alias AllocT = SystemAllocator)(auto ref T value, AllocatorWrapperOf!AllocT alloc = AllocatorWrapperOf!AllocT.init)
{
    return typeof(return)(value, alloc);
}