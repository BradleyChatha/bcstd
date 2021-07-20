module libd.algorithm.filtering;

import libd.algorithm;

auto where(alias Filter, RangeT)(RangeT range)
{
    alias ElementT = typeof(range.front);

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

        bool empty()
        {
            return this._empty;
        }

        ElementT front()
        {
            return this._front;
        }

        void popFront()
        {
            for(; !this._range.empty; this._range.popFront())
            {
                auto value = this._range.front;
                if(Filter(value))
                {
                    this._front = value;
                    this._range.popFront();
                    return;
                }
            }

            this._empty = true;
        }
    }

    return Range(range);
}