module bcstd.data.hash;

import core.bitop : rol;

// Conversion of the canonical source, wrapped into an incremental struct.
// Original code is public domain with copyright waived.
@nogc nothrow
struct HashMurmur3_32(uint Seed)
{
    static if(Seed == -1)
    {
        private uint _seed;
        @safe
        this(uint seed) pure
        {
            this._seed = seed;
        }
    }
    else
        private uint _seed = Seed;

    @property @safe
    uint value() pure const
    {
        return this._seed;
    }

    @trusted
    void put(const void[] key)
    {
        const data    = cast(const(ubyte)*)key.ptr;
        const nblocks = cast(uint)(key.length / 4);

        uint h1 = this._seed;

        const uint c1 = 0xcc9e2d51;
        const uint c2 = 0x1b873593;

        const blocks = cast(uint*)(data + (nblocks * 4));

        for(int i = -nblocks; i; i++)
        {
            version(LittleEndian)
                uint k1 = blocks[i];
            else
                static assert(false, "TODO for Big endian");

            k1 *= c1;
            k1 = rol(k1, 15);
            k1 *= c2;

            h1 ^= k1;
            h1 = rol(h1, 13);
            h1 = h1*5+0xe6546b64; // ok
        }

        const tail = (data + (nblocks * 4));

        uint k1 = 0;

        final switch(key.length & 3)
        {
            case 3: k1 ^= tail[2] << 16; goto case;
            case 2: k1 ^= tail[1] << 8; goto case;
            case 1: k1 ^= tail[0]; goto case;
            case 0: k1 *= c1;
                    k1 = rol(k1, 15);
                    k1 *= c2;
                    h1 ^= k1;
                    break;
        }

        h1 ^= key.length;
        h1 ^= h1 >> 16;
        h1 *= 0x85ebca6b;
        h1 ^= h1 >> 13;
        h1 *= 0xc2b2ae35;
        h1 ^= h1 >> 16;
        this._seed = h1;
    }
}
///
@("Murmur3_32")
unittest
{
    import std.format : format;

    const key      = "The quick brown fox jumps over the lazy dog.";
    const seed     = 0;
    const expected = 0xD5C48BFC;

    HashMurmur3_32!seed hash;
    hash.put(key);
    assert(hash.value == expected, "Expected %X but got %X".format(expected, hash.value));
}

alias Murmur3_32 = HashMurmur3_32!104_729; // Constant taken from the internet somewhere.
alias RtMurmur3_32 = HashMurmur3_32!(-1);