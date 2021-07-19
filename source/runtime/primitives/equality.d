module runtime.primitives.equality;

bool __equals(T)(scope const T[] a, scope const T[] b)
{
    if(a.length != b.length)
        return false;

    static if(is(T == struct) && !__traits(isPOD, T))
    {
        foreach(i, ref item; a)
        {
            if(item != b[i])
                return false;
        }
    }
    else
    {
        if(!__ctfe)
        {
            import runtime.dynamicfuncs;
            const result = ()@trusted{
                return memequal(a.ptr, b.ptr, T.sizeof * a.length);
            }();
            if(!result)
                return false;
        }
        else
        {
            foreach(i, ref item; a)
            {
                if(item != b[i])
                    return false;
            }
        }
    }

    return true;
}