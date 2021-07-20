module libd.data.hash;

import libd.util.bitwise : rol;

// Doesn't include all prime numbers in series as this is used by things like HashMap for determining size.
// Taken from https://github.com/skarupke/flat_hash_map/blob/master/flat_hash_map.hpp#L1124
// Credit to skarupe under an unknown license.
immutable PrimeNumberForSizeLookup = [
    2UL, 13UL, 17UL, 23UL, 29UL, 37UL, 47UL,
    59UL, 73UL, 97UL, 127UL, 151UL, 197UL, 251UL, 313UL, 397UL,
    499UL, 631UL, 797UL, 1009UL, 1259UL, 1597UL, 2011UL, 2539UL,
    3203UL, 4027UL, 5087UL, 6421UL, 8089UL, 10193UL, 12853UL, 16193UL,
    20399UL, 25717UL, 32401UL, 40823UL, 51437UL, 64811UL, 81649UL,
    102877UL, 129607UL, 163307UL, 205759UL, 259229UL, 326617UL,
    411527UL, 518509UL, 653267UL, 823117UL, 1037059UL, 1306601UL,
    1646237UL, 2074129UL, 2613229UL, 3292489UL, 4148279UL, 5226491UL,
    6584983UL, 8296553UL, 10453007UL, 13169977UL, 16593127UL, 20906033UL,
    26339969UL, 33186281UL, 41812097UL, 52679969UL, 66372617UL,
    83624237UL, 105359939UL, 132745199UL, 167248483UL, 210719881UL,
    265490441UL, 334496971UL, 421439783UL, 530980861UL, 668993977UL,
    842879579UL, 1061961721UL, 1337987929UL, 1685759167UL, 2123923447UL,
    2675975881UL, 3371518343UL, 4247846927UL, 5351951779UL, 6743036717UL,
    8495693897UL, 10703903591UL, 13486073473UL, 16991387857UL,
    21407807219UL, 26972146961UL, 33982775741UL, 42815614441UL,
    53944293929UL, 67965551447UL, 85631228929UL, 107888587883UL,
    135931102921UL, 171262457903UL, 215777175787UL, 271862205833UL,
    342524915839UL, 431554351609UL, 543724411781UL, 685049831731UL,
    863108703229UL, 1087448823553UL, 1370099663459UL, 1726217406467UL,
    2174897647073UL, 2740199326961UL, 3452434812973UL, 4349795294267UL,
    5480398654009UL, 6904869625999UL, 8699590588571UL, 10960797308051UL,
    13809739252051UL, 17399181177241UL, 21921594616111UL, 27619478504183UL,
    34798362354533UL, 43843189232363UL, 55238957008387UL, 69596724709081UL,
    87686378464759UL, 110477914016779UL, 139193449418173UL,
    175372756929481UL, 220955828033581UL, 278386898836457UL,
    350745513859007UL, 441911656067171UL, 556773797672909UL,
    701491027718027UL, 883823312134381UL, 1113547595345903UL,
    1402982055436147UL, 1767646624268779UL, 2227095190691797UL,
    2805964110872297UL, 3535293248537579UL, 4454190381383713UL,
    5611928221744609UL, 7070586497075177UL, 8908380762767489UL,
    11223856443489329UL, 14141172994150357UL, 17816761525534927UL,
    22447712886978529UL, 28282345988300791UL, 35633523051069991UL,
    44895425773957261UL, 56564691976601587UL, 71267046102139967UL,
    89790851547914507UL, 113129383953203213UL, 142534092204280003UL,
    179581703095829107UL, 226258767906406483UL, 285068184408560057UL,
    359163406191658253UL, 452517535812813007UL, 570136368817120201UL,
    718326812383316683UL, 905035071625626043UL, 1140272737634240411UL,
    1436653624766633509UL, 1810070143251252131UL, 2280545475268481167UL,
    2873307249533267101UL, 3620140286502504283UL, 4561090950536962147UL,
    5746614499066534157UL, 7240280573005008577UL, 9122181901073924329UL,
    11493228998133068689UL, 14480561146010017169UL, 18446744073709551557UL
];

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
        const data    = (cast(const(ubyte)[])key).ptr;
        const nblocks = cast(uint)(key.length / 4);

        uint h1 = this._seed;

        const uint c1 = 0xcc9e2d51;
        const uint c2 = 0x1b873593;

        if(!__ctfe)
        {
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
        }
        else // CTFE can't do reinterpret casts of different byte widths.
        {
            for(int i = nblocks; i; i--)
            {
                const blockI = (i * 4);
                uint k1 = (
                    (data[blockI-4] << 24)
                  | (data[blockI-3] << 16)
                  | (data[blockI-2] << 8)
                  | (data[blockI-1] << 0)
                );

                k1 *= c1;
                k1 = rol(k1, 15);
                k1 *= c2;

                h1 ^= k1;
                h1 = rol(h1, 13);
                h1 = h1*5+0xe6546b64;
            }
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
    const key      = "The quick brown fox jumps over the lazy dog.";
    const seed     = 0;
    const expected = 0xD5C48BFC;

    HashMurmur3_32!seed hash;
    hash.put(key);
    assert(hash.value == expected);
}

alias Murmur3_32 = HashMurmur3_32!104_729; // Constant taken from the internet somewhere.
alias RtMurmur3_32 = HashMurmur3_32!(-1);

uint murmur3_32HashOf(T)(auto ref T value)
{
    Murmur3_32 hasher;
    hasher.put((&value)[0..1]);
    return hasher.value;
}