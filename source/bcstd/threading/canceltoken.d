module bcstd.threading.canceltoken;

import core.atomic;

shared struct CancelToken
{
    // Put it on the heap/smart pointer.
    // This struct doesn't make too much sense without reference semantics.
    @disable this(this){}

    @nogc nothrow:
    private bool _shouldCancel;

    @property @safe
    void cancel() pure
    {
        atomicStore(this._shouldCancel, true);
    }

    @property @safe 
    bool isCancelRequested() pure const
    {
        return atomicLoad(this._shouldCancel);
    }
}