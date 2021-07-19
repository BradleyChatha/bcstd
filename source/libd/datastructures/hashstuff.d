module libd.datastructures.hashstuff;

import libd.memory, libd.data, libd.datastructures.array, libd.datastructures.growth, libd.algorithm.common,
       libd.meta.traits;

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

    // Moving things we don't need to move is *suuuper* slow, so types can explicitly say if they prefer being moved.
    enum KeyOptimise   = BitmaskUda!(OptimisationHint, KeyT);
    enum ValueOptimise = BitmaskUda!(OptimisationHint, ValueT);
    enum MoveKey       = (KeyOptimise & OptimisationHint.preferMoveOverCopy) > 0   || !isCopyable!KeyT;
    enum MoveValue     = (ValueOptimise & OptimisationHint.preferMoveOverCopy) > 0 || !isCopyable!ValueT;

    static struct Node
    {
        KeyT key;
        ValueT value;
        ubyte distance = ubyte.max;
    }

    private Array!(Node, AllocT) _array;
    private size_t _fakeCapacity;
    private size_t _fakeMaxLoadCapacity;
    private size_t _length;
    private ubyte  _primeIndex;
    private ubyte  _probeLimit;

    @nogc nothrow:

    this(AllocatorWrapperOf!AllocT alloc)
    {
        this._array = typeof(_array)(alloc);
    }

    void put()(KeyT key, ValueT value)
    {
        bool alreadyExists, wasSwap, wasSwapAtAnyPoint, ___;
        KeyT currKey, _;
        ValueT currValue, __;
        if(this._length >= this._fakeMaxLoadCapacity
         || !this.putInto(this._array, key, value, alreadyExists, wasSwap, currKey, currValue) // failed insertion
        )
        {
            import core.stdc.math : log2, ceil; // As if I know how to write log2 myself ;^)

            typeof(_array) nextArray;
            const oldLength = this._length;
            while(true)
            {
                const nextPrime    = nextPrimeSize(this._primeIndex);
                const nextLimit    = cast(ubyte)log2(cast(double)nextPrime);
                const nextRealSize = nextPrime + nextLimit;
                const nextMaxSize  = cast(size_t)(ceil(cast(double)nextPrime * maxLoadFactor));
                this._probeLimit   = nextLimit;
                this._fakeCapacity = nextPrime;
                this._fakeMaxLoadCapacity = nextMaxSize;
                nextArray.length = nextRealSize;

                bool reloop = false;
                size_t insertCount;
                foreach(ref node; this._array)
                {
                    if(node.distance == ubyte.max)
                        continue;
                    if(!this.putInto(nextArray, node.key, node.value, alreadyExists, ___, _, __))
                    {
                        reloop = true;
                        break;
                    }
                    if(++insertCount == oldLength)
                        break;
                }
                
                if(reloop)
                {
                    emplaceInit(nextArray);
                    continue;
                }

                const result = (wasSwap || wasSwapAtAnyPoint)
                    ? this.putInto(nextArray, currKey, currValue, alreadyExists, wasSwap, currKey, currValue)
                    : this.putInto(nextArray, key, value, alreadyExists, wasSwap, currKey, currValue);
                wasSwapAtAnyPoint = wasSwapAtAnyPoint || wasSwap;
                if(!result)
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
        return this.getNodeAt(key) !is null;
    }
    
    inout(ValueT) getAt()(auto ref KeyT key) inout
    {
        auto result = this.getNodeAt(key);
        assert(result !is null, "Could not find key.");
        return result.value;
    }

    ref inout(ValueT) getAtByRef()(auto ref KeyT key) inout
    {
        auto ptr = this.getNodeAt(key);
        assert(ptr !is null, "Could not find key.");
        return ptr.value;
    }

    inout(ValueT) getAtOrDefault()(auto ref KeyT key, auto ref scope return ValueT default_ = ValueT.init) inout
    {
        auto result = this.getNodeAt(key);
        return (result) ? result.value : cast(inout)default_;
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
        const index  = toHashToPrimeIndex!(Hasher, KeyT)(key, this._primeIndex - 1);
        auto nodePtr = &this._array[index]; // bypass bounds checking, as our overallocation should ensure this is always in bounds.
        foreach(i; 0..this._probeLimit)
        {
            auto ptr = &nodePtr[i];
            if(ptr.key == key)
                return ptr;
        }
        return null;
    }
    
    // Interestingly, LDC automatically inlines this function when optimising o.o
    private bool putInto()(
        ref typeof(_array) array, 
        auto ref KeyT key, 
        auto ref ValueT value, 
        out bool alreadyExists,
        out bool wasSwap,
        ref KeyT currKey,
        ref ValueT currValue
    )
    {
        static if(MoveKey)   move(key, currKey);     else currKey = key;
        static if(MoveValue) move(value, currValue); else currValue = value;

        const index    = toHashToPrimeIndex!(Hasher, KeyT)(key, this._primeIndex-1);
        const length   = array.length;
        auto arrayPtr  = array[].ptr; // bypass bounds checking as this should in theory be completely @safe to access.
        ubyte distance = 255;
        for(size_t i = index; i < length; i++)
        {
            distance++;
            if(distance >= this._probeLimit)
                break;

            auto nodePtr = &arrayPtr[i];

            if(nodePtr.distance == ubyte.max)
            {
                static if(MoveKey)   move(currKey, nodePtr.key);     else nodePtr.key = currKey;
                static if(MoveValue) move(currValue, nodePtr.value); else nodePtr.value = currValue;
                nodePtr.distance = distance;
                return true;
            }
            else if(nodePtr.distance < distance)
            {
                wasSwap = true;

                KeyT   tempKey;
                ValueT tempValue;
                ubyte  tempDistance;

                static if(MoveKey)   move(nodePtr.key, tempKey);     else tempKey = nodePtr.key;
                static if(MoveValue) move(nodePtr.value, tempValue); else tempValue = nodePtr.value;
                tempDistance = nodePtr.distance;

                static if(MoveKey)   move(currKey, nodePtr.key);     else nodePtr.key = currKey;
                static if(MoveValue) move(currValue, nodePtr.value); else nodePtr.value = currValue;
                nodePtr.distance = distance;

                static if(MoveKey)   move(tempKey, currKey);     else currKey   = tempKey;
                static if(MoveValue) move(tempValue, currValue); else currValue = tempValue;
                distance = tempDistance;
            }
            else if(nodePtr.key == currKey)
            {
                static if(MoveKey)   move(currKey, nodePtr.key); // So things stay predictable in terms of what OnMove and such do.
                static if(MoveValue) move(currValue, nodePtr.value); else nodePtr.value = currValue;
                alreadyExists = true;
                return true;
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
    //@(OptimisationHint.preferMoveOverCopy)
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
    assert(pblit == dtor+1);
    h.__xdtor();
    assert(pblit == dtor);

    pblit = dtor = 0;
    emplaceInit(h);
    h.put("test", s);
    h.put("test", s);
    assert(h.length == 1);
    assert(pblit == dtor+1);
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

    RobinHoodHashMap!(int, S) his;
    pblit = dtor = 0;
    foreach(i; 0..10_000)
        his.put(i, s);
    his.__xdtor();
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
    enum AMOUNT = 10_000;
    RobinHoodHashMap!(int, int) h;
    foreach(i; 0..AMOUNT)
    {
        if(h.length != i)
            assert(false);
        if(i == 0x027d)
            int d = 0;
        h.put(i, i);
    }
    assert(h.length == AMOUNT);
    foreach(i; 0..AMOUNT)
        h.getAt(i);
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