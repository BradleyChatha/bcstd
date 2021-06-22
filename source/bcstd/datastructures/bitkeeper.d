module bcstd.datastructures.bitkeeper;

import bcstd.datastructures._bitinfo;
import bcstd.util.errorhandling;
import bcstd.util.maths : alignTo;

struct BitKeeperSlice
{
    private size_t startByte;
    private ubyte  startBit;
    private size_t bitCount;

    invariant(startBit >= 0 && startBit < 8);
    invariant(startByte + startBit + bitCount == 0 || bitCount > 0);

    @property @safe @nogc
    size_t bitIndex() nothrow pure const
    {
        return (this.startByte * 8) + this.startBit;
    }
}

struct BitKeeper
{
    private ubyte[] _bytes;
    private size_t  _maxBitsToUse;
    private size_t  _bitsInUse;

    @disable this(this){}

    @safe @nogc nothrow:

    this(ubyte[] bytes, size_t maxBitsToUse)
    {
        this._bytes = bytes;
        this._maxBitsToUse = maxBitsToUse;
        assert(this._maxBitsToUse/8 <= bytes.length, "Not enough bytes were provided for the given maxBitsToUse value.");
    }

    SimpleResult!BitKeeperSlice alloc(size_t bitCount)
    {
        assert(this._bytes !is null, "This BitKeeper hasn't been initialised.");
        if(bitCount == 0)
            return typeof(return)(raise("BitCount cannot be 0."));
        else if(bitCount >= this._maxBitsToUse - this._bitsInUse)
            return typeof(return)(raise("Not enough total bits available."));

        for(size_t i = 0; i < this._bytes.length; i++)
        {
            const byte_ = this._bytes[i];
            if(byte_ == 0xFF)
                continue;

            const info = BIT_INFO[byte_];
            if(info.largestBitRangeCount >= bitCount)
            {
                const range = BitRange(info.bitRangeForSize[bitCount-1].start, cast(ubyte)bitCount);
                const mask  = rangeToMask(range);
                this._bytes[i] |= mask;
                return typeof(return)(BitKeeperSlice(
                    i, range.start, bitCount
                ));
            }
            else if(info.flags & BitInfoFlags.hasSuffixZero)
            {
                const startByte = i;
                const startRange = info.bitRangeForSuffix;
                auto remainingBits = bitCount - startRange.count;
                assert(remainingBits < bitCount);

                i++;
                while(true)
                {
                    if(i >= this._bytes.length)
                        return typeof(return)(raise("Cannot find a long enough, continous range of bits."));
                    
                    const nextByte = this._bytes[i];
                    const nextByteInfo = BIT_INFO[nextByte];
                    
                    if(nextByte == 0)
                    {
                        if(remainingBits <= 8)
                        {
                            const range = BitRange(0, cast(ubyte)remainingBits);
                            const mask  = rangeToMask(range);
                            this._bytes[i] |= mask;
                            // Fallthrough to end
                        }
                        else
                        {
                            i++;
                            remainingBits -= 8;
                            continue;
                        }
                    }
                    else if
                    (
                        !(nextByteInfo.flags & BitInfoFlags.hasPrefixZero)
                     ||  nextByteInfo.bitRangeForPrefix.count < remainingBits
                     ||  nextByte == 0xFF
                    )
                    {
                        i--; // Negate the for loop's next i++
                        break; // Failed match, try again with further bytes.
                    }
                    else
                        this._bytes[i] |= rangeToMask(BitRange(0, cast(ubyte)remainingBits));

                    const inbetweenBytes = i - startByte;
                    if(inbetweenBytes >= 2)
                    {
                        foreach(byteI; 1..inbetweenBytes)
                            this._bytes[startByte+byteI] = 0xFF;
                    }
                    this._bytes[startByte] |= rangeToMask(startRange);
                    this._bitsInUse += bitCount;
                    return typeof(return)(BitKeeperSlice(
                        startByte, startRange.start, bitCount 
                    ));
                }
            }
        }

        return typeof(return)(raise("Cannot find a long enough, continous range of bits."));
    }

    void free(BitKeeperSlice slice)
    {
        const startByteBitsFromStartToEnd = 8 - slice.startBit;
        if(startByteBitsFromStartToEnd > slice.bitCount) // Slice is only in a single byte.
        {
            this._bytes[slice.startByte] &= ~cast(int)rangeToMask(BitRange(slice.startBit, cast(ubyte)slice.bitCount));
            return;
        } // Slice is multi-byte.

        this._bytes[slice.startByte] &= ~cast(int)rangeToMask(BitRange(slice.startBit, cast(ubyte)startByteBitsFromStartToEnd));

        // Clear the inbetween full bytes.
        auto byteI = slice.startByte+1;
        auto remainingBits = slice.bitCount - startByteBitsFromStartToEnd;
        while(remainingBits >= 8)
        {
            this._bytes[byteI++] = 0;
            remainingBits -= 8;
        }

        // Clear the end byte.
        this._bytes[byteI] &= ~cast(int)rangeToMask(BitRange(0, cast(ubyte)remainingBits));
        this._bitsInUse -= slice.bitCount;
    }

    size_t capacityInBits() pure const
    {
        return this._maxBitsToUse;
    }

    size_t lengthInBits() pure const
    {
        return this._bitsInUse;
    }
}
///
@("BitKeeper")
unittest
{
    auto buffer = new ubyte[3];
    auto bits = BitKeeper(buffer, 3*8);

    // NOTE: User code can't manually create BitKeeperSlices like the unittest can.

    // Single-byte
    assert(bits.alloc(1).assertValidResult == BitKeeperSlice(0, 0, 1));
    assert(buffer[0] == 1);
    bits.free(BitKeeperSlice(0, 0, 1));
    assert(buffer[0] == 0);
    assert(bits.alloc(1).assertValidResult == BitKeeperSlice(0, 0, 1));
    assert(bits.alloc(3).assertValidResult == BitKeeperSlice(0, 1, 3));
    assert(buffer[0] == 0b0000_1111);
    bits.free(BitKeeperSlice(0, 1, 2));
    assert(buffer[0] == 0b0000_1001);
    assert(bits.alloc(1).assertValidResult == BitKeeperSlice(0, 1, 1));
    assert(bits.alloc(2).assertValidResult == BitKeeperSlice(0, 4, 2));
    assert(buffer[0] == 0b0011_1011);
    buffer[0] = 0;

    // Two bytes
    assert(bits.alloc(7).assertValidResult == BitKeeperSlice(0, 0, 7));
    assert(bits.alloc(3).assertValidResult == BitKeeperSlice(0, 7, 3));
    assert(buffer[0] == 0xFF);
    assert(buffer[1] == 0b0000_0011);
    bits.free(BitKeeperSlice(0, 7, 2));
    assert(buffer[0] == 0b0111_1111);
    assert(buffer[1] == 0b0000_0010);
    assert(bits.alloc(3).assertValidResult == BitKeeperSlice(1, 2, 3));
    assert(buffer[0] == 0b0111_1111);
    assert(buffer[1] == 0b0001_1110);
    buffer[0..2] = 0;

    // Multi-byte
    assert(bits.alloc(18).assertValidResult == BitKeeperSlice(0, 0, 18));
    assert(buffer[0] == 0xFF);
    assert(buffer[1] == 0xFF);
    assert(buffer[2] == 0b0000_0011);
    bits.free(BitKeeperSlice(0, 0, 18));
    assert(buffer[0] == 0);
    assert(buffer[1] == 0);
    assert(buffer[2] == 0);
}

private:

@safe @nogc
ubyte rangeToMask(const BitRange range) nothrow pure
{
    return BIT_MASKS[(range.start * 10) + range.count];
}