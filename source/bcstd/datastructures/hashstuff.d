module bcstd.datastructures.hashstuff;

import bcstd.memory, bcstd.data, bcstd.datastructures.array;

struct KeyValuePair(alias KeyT, alias ValueT)
{
    KeyT key;
    ValueT value;
}

struct KeyValueRefPair(alias KeyT, alias ValueT)
{
    KeyT* key;
    ValueT* value;
}

struct RobinHoodHashMap(
    alias KeyT, 
    alias ValueT, 
    alias AllocT = SystemAllocator, 
    alias Hasher = murmur3_32HashOf, 
    double maxLoadFactor = 0.8
)
{
    static assert(maxLoadFactor > 0, "The load factor cannot be 0 or negative.");

    static struct Node
    {
        KeyT key;
        ValueT value;
        ubyte distance = ubyte.max;
    }

    private Array!(Node, AllocT) _array;
    private size_t _fakeCapacity;
    private size_t _length;
    private ubyte  _primeIndex;
    private ubyte  _probeLimit;

    @nogc nothrow:

    this(AllocatorWrapperOf!AllocT alloc)
    {
        this._array = typeof(_array)(alloc);
    }

    void put()(auto ref KeyT key, auto ref ValueT value)
    {
        bool alreadyExists;
        if(
            this._array.length == 0
         || ((cast(double)this._length / this._fakeCapacity) >= maxLoadFactor)
         || !this.putInto(this._array, key, value, alreadyExists) // failed insertion
        )
        {
            import core.stdc.math : log2; // As if I know how to write this myself ;^)

            typeof(_array) nextArray;
            const oldLength = this._length;
            while(true)
            {
                const nextPrime    = nextPrimeSize(this._primeIndex);
                const nextLimit    = cast(ubyte)log2(cast(double)nextPrime);
                const nextRealSize = nextPrime + nextLimit;
                nextArray.length   = nextRealSize;

                this._probeLimit   = nextLimit;
                this._fakeCapacity = nextPrime;

                bool reloop = false;
                size_t insertCount;
                foreach(ref node; this._array)
                {
                    if(node.distance == ubyte.max)
                        continue;
                    if(!this.putInto(nextArray, node.key, node.value, alreadyExists))
                    {
                        reloop = true;
                        break;
                    }
                    if(++insertCount == oldLength)
                        break;
                }
                if(reloop || !this.putInto(nextArray, key, value, alreadyExists))
                {
                    emplaceInit(nextArray);
                    continue;
                }

                move(nextArray, this._array);
                break;
            }
        }

        this._length += !alreadyExists;
    }

    bool removeAt()(auto ref KeyT key)
    {
        ValueT v;
        return this.removeAt(key, v);
    }

    bool removeAt()(auto ref KeyT key, ref ValueT outValue)
    {
        if(this._primeIndex == 0)
            return false;
        const index = toHashToPrimeIndex!(Hasher, KeyT)(key, this._primeIndex - 1);
        foreach(i; 0..this._probeLimit)
        {
            auto ptr = &this._array[index+i];
            if(ptr.key == key)
            {
                ValueT value;
                move(ptr.value, value);
                emplaceInit(*ptr);

                auto shiftIndex = index+i+1;
                auto lastPtr    = ptr;
                while(shiftIndex < this._array.length)
                {
                    auto currPtr = &this._array[shiftIndex++];
                    if(currPtr.distance == 0 || currPtr.distance == 255)
                        break;
                    move(*currPtr, *lastPtr);
                    lastPtr = currPtr;
                }

                move(value, outValue);
                this._length--;
                return true;
            }
        }
        return false;
    }

    bool containsKey()(auto ref KeyT key) const
    {
        return this.getPtrUnsafeAt(key) !is null;
    }

    inout(ValueT) getAt()(auto ref KeyT key) inout
    {
        auto result = this.getPtrUnsafeAt(key);
        assert(result !is null, "Could not find key.");
        return *result;
    }

    inout(ValueT) getAtOrDefault()(auto ref KeyT key, auto ref scope return ValueT default_ = ValueT.init) inout
    {
        auto result = this.getPtrUnsafeAt(key);
        return (result) ? *result : default_;
    }

    inout(ValueT)* getPtrUnsafeAt()(auto ref KeyT key) inout
    {
        auto result = this.getNodeAt(key);
        return (result) ? &result.value : null;
    }

    @property @safe
    size_t length() const
    {
        return this._length;
    }

    @property
    auto range()
    {
        alias HashMapT = typeof(this);

        static struct R
        {
            HashMapT* ptr;
            KeyValueRefPair!(KeyT, ValueT) _front;
            size_t lengthAtStart;
            size_t iteratedOver;
            size_t index;
            bool _empty = true;

            @nogc nothrow:

            this(HashMapT* hashmap)
            {
                this.ptr = hashmap;
                this.lengthAtStart = hashmap.length;
                this._empty = false;
                this.popFront();
            }

            void popFront()
            {
                assert(!this.empty, "Cannot pop an empty range.");
                if(this.iteratedOver == this.lengthAtStart)
                {
                    this._empty = true;
                    return;
                }
                foreach(i; this.index..this.ptr._array.length)
                {
                    if(ptr._array[i].distance != ubyte.max)
                    {
                        this.iteratedOver++;
                        this._front = typeof(_front)(
                            &ptr._array[i].key,
                            &ptr._array[i].value
                        );
                        this.index = i+1;
                        return;
                    }
                }
                assert(false, "?? Could not find next front?");
            }

            bool empty()
            {
                if(this.ptr is null)
                    return true;
                assert(this.ptr.length == this.lengthAtStart, "Please do not modify the hashmap during iteration.");
                return this._empty;
            }

            typeof(_front) front()
            {
                assert(!this.empty, "Cannot access front of empty range.");
                return this._front;
            }
        }

        return R(&this);
    }

    private inout(Node)* getNodeAt()(auto ref KeyT key) inout
    {
        if(this._primeIndex == 0)
            return null;
        const index = toHashToPrimeIndex!(Hasher, KeyT)(key, this._primeIndex - 1);
        foreach(i; 0..this._probeLimit)
        {
            auto ptr = &this._array[index+i];
            if(ptr.key == key)
                return ptr;
        }
        return null;
    }
    
    private bool putInto()(ref typeof(_array) array, auto ref KeyT key, auto ref ValueT value, out bool alreadyExists)
    {
        KeyT   currKey   = key;
        ValueT currValue = value;

        const index = toHashToPrimeIndex!(Hasher, KeyT)(key, this._primeIndex-1);

        for(ubyte distance = 0; distance < this._probeLimit; distance++)
        {
            auto nodePtr = &array[index+distance];

            if(nodePtr.distance == ubyte.max)
            {
                move(currKey, nodePtr.key);
                move(currValue, nodePtr.value);
                nodePtr.distance = distance;
                return true;
            }
            else if(nodePtr.key == currKey)
            {
                move(currKey, nodePtr.key); // So things stay predictable in terms of what OnMove and such do.
                move(currValue, nodePtr.value);
                alreadyExists = true;
                return true;
            }
            else if(nodePtr.distance < distance)
            {
                KeyT   tempKey;
                ValueT tempValue;
                ubyte  tempDistance;

                move(nodePtr.key, tempKey);
                move(nodePtr.value, tempValue);
                tempDistance = nodePtr.distance;

                move(currKey, nodePtr.key);
                move(currValue, nodePtr.value);
                nodePtr.distance = distance;

                move(tempKey, currKey);
                move(tempValue, currValue);
                distance = tempDistance;
            }
        }

        return false;
    }
}
@("RobinHoodHashMap")
unittest
{
    uint pblit;
    uint dtor;
    static struct S
    {
        @nogc nothrow:
        uint* pblit;
        uint* dtor;

        this(this)
        {
            if(pblit)
                (*pblit)++;
        }

        ~this()
        {
            if(dtor)
                (*dtor)++;
        }
    }

    S s = S(&pblit, &dtor);
    RobinHoodHashMap!(string, S) h;
    
    h.put("test", s);
    assert(h.length == 1);
    assert(h.containsKey("test"));
    assert(!h.containsKey("tesT"));
    assert(pblit == 1);
    assert(dtor == 0);
    h.__xdtor();
    assert(pblit == dtor);

    pblit = dtor = 0;
    emplaceInit(h);
    h.put("test", s);
    h.put("test", s);
    assert(h.length == 1);
    assert(pblit == 2);
    assert(dtor  == 1);
    h.put("test2", s);
    assert(h.length == 2);
    assert(pblit == dtor+2);
    h.__xdtor();
    assert(pblit == dtor);
    
    pblit = dtor = 0;
    emplaceInit(h);
    h.put("test", s);
    h.put("test2", s);
    assert(pblit == dtor+2);
    h.removeAt("test");
    assert(h.length == 1);
    assert(pblit == dtor+1);
    h.__xdtor();
    assert(pblit == dtor);

    RobinHoodHashMap!(string, int) hi;

    hi.put("one", 0);
    hi.put("two", 2);
    assert(hi.getPtrUnsafeAt("one") !is null);
    *hi.getPtrUnsafeAt("one") = 1;
    assert(hi.getAt("one") == 1);
    assert(hi.getAt("two") == 2);
    assert(hi.getAtOrDefault("three", 3) == 3);
    
    int result;
    assert(hi.removeAt("two", result));
    assert(result == 2);
    assert(!hi.removeAt("two"));
    assert(hi.removeAt("one"));

    hi.put("one", 2);
    hi.put("two", 4);
    assert(hi.length == 2);
    assert(hi.getAt("two") == 4);

    auto r = hi.range;
    assert(!r.empty);
    assert(*r.front.key == "one" || *r.front.key == "two");
    assert(*r.front.value == 2 || *r.front.value == 4);
    r.popFront();
    assert(!r.empty);
    assert(*r.front.key == "one" || *r.front.key == "two");
    assert(*r.front.value == 2 || *r.front.value == 4);
    r.popFront();
    assert(r.empty);

    result = 0;
    foreach(kvp; hi.range) 
        result += *kvp.value;
    assert(result == 6);
}
@("RobinHoodHashMap - 10_000 ints")
unittest
{
    RobinHoodHashMap!(int, int) h;
    foreach(i; 0..10_000)
        h.put(i, i);
}

@safe @nogc 
private size_t nextPrimeSize(ref ubyte index) nothrow pure
{
    return PrimeNumberForSizeLookup[index++];
}

@trusted @nogc
private auto toHashToPrimeIndex(alias Hasher, alias T)(auto ref T value, const int primeIndex) nothrow pure
{
    static if(is(T == struct) && __traits(hasMember, T, "toHash"))
        const hash = value.toHash();
    else
        const hash = Hasher(value);

    // Division (inc modulo) is super super super slow on unknown numbers.
    // Doing things this way allows the compiler to generated optimised opcodes since it knows the divisor beforehand.
    switch(primeIndex)
    {
        static foreach(i, prime; PrimeNumberForSizeLookup)
            case i: return hash % prime;
        default: break;
    }

    assert(false, "Index too high?");
}