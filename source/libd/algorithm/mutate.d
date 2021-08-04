module libd.algorithm.mutate;

auto map(alias Mapper, RangeT)(RangeT range)
{
    import libd.algorithm;

    alias ElementT = typeof(Mapper(range.front));
    static struct Range
    {
        private RangeT _range;
        private ElementT _front;
        private bool _empty;

        @nogc nothrow:

        this(RangeT range)
        {
            this._range = range;
            this.popFront();
        }

        void popFront()
        {
            if(this._range.empty)
            {
                this._empty = true;
                return;
            }

            this._front = Mapper(this._range.front);
            this._range.popFront();
        }

        bool empty()
        {
            return this._empty;
        }

        ElementT front()
        {
            return this._front;
        }
    }

    return Range(range);
}
///
@("map")
unittest
{
    import libd.data.conv, libd.algorithm;

    Array!int nums;
    nums.put(1, 2, 3);

    String[3] expected = [String("1"), String("2"), String("3")];
    auto range = nums.range.map!(n => n.to!String);
    assert(range.equals!((a,b) => a == b)(expected[0..$]));
}