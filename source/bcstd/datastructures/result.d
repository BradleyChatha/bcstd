module bcstd.datastructures.result;

import bcstd.object, bcstd.datastructures.sumtype;

struct SimpleResult(T)
{
    private union ValueOrError
    {
        static if(!is(T == void)) T value;
        bcstring error;
    }

    private bool _isValid;
    private SumType!ValueOrError _value;

    static if(!is(T == void))
    this()(auto ref T value)
    {
        this._value = value;
        this._isValid = true;
    }

    this(bcstring error)
    {
        this._value = error;
        this._isValid = false;
    }

    @property @safe @nogc
    bool isValid() nothrow pure const
    {
        return this._isValid;
    }

    static if(!is(T == void))
    @property
    ref T value()()
    {
        assert(this._isValid, "Attempted to get value of invalid result.");
        return this._value.get!T;
    }

    @property
    bcstring error()
    {
        assert(!this._isValid, "Attempted to get value of not-invalid result.");
        return this._value.get!bcstring;
    }
}