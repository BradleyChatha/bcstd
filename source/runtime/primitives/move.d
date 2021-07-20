module runtime.primitives.move;

void __ArrayDtor(T)(T[] array)
{
    static if(__traits(hasMember, T, "__xdtor"))
    {
        foreach(ref value; array)
            value.__xdtor();
    }
}