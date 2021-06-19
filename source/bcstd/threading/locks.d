module bcstd.threading.locks;

import core.atomic : cas;

struct LockBusyCas
{
    private bool _lock;
    @disable this(this){}

    @nogc @safe nothrow:

    bool tryLock()
    {
        return cas(&this._lock, false, true);
    }

    void lock()
    {
        while(!this.tryLock()){}
    }

    void unlock()
    {
        assert(this.isLocked, "unlock should never be called unless the lock is locked! This indicates a logic/concurrency bug.");
        if(!cas(&this._lock, true, false))
            assert(false, "This shouldn't fail?");
    }

    bool isLocked() const
    {
        return this._lock;
    }
}