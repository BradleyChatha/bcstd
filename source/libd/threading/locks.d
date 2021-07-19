module libd.threading.locks;

import libd.threading.atomic : atomicCas;

shared struct LockBusyCas
{
    private bool _lock;
    @disable this(this){}

    @nogc @safe nothrow:

    bool tryLock()
    {
        return atomicCas(this._lock, false, true);
    }

    void lock()
    {
        while(!this.tryLock()){}
    }

    void unlock()
    {
        assert(this.isLocked, "unlock should never be called unless the lock is locked! This indicates a logic/concurrency bug.");
        if(!atomicCas(this._lock, true, false))
            assert(false, "This shouldn't fail?");
    }

    bool isLocked() const
    {
        return this._lock;
    }
}

shared struct Lockable(ValueT, LockT = LockBusyCas)
{
    private LockT  _lock;
    private ValueT _value;

    @nogc nothrow:

    void access(scope void delegate(scope ref ValueT) @nogc nothrow func)
    {
        this._lock.lock();
        scope(exit) this._lock.unlock();

        // Casting away shared since the given delegate is using it when only
        // one thread should actually be accessing it.
        //
        // This saves the need for `ValueT` to implement a shared interface.
        auto notShared = cast(ValueT*)&this._value;
        func(*notShared);
    }
}