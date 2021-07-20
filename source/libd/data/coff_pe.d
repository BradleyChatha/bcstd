module libd.data.coff_pe;

import libd.datastructures : Array, Shared, makeShared;

@nogc nothrow:

enum DOS_HEADER_MAGIC = 0x5A4D; // MZ
enum COFF_HEADER_MAGIC = "PE\0\0";

enum CoffMachineType : ushort
{
    IMAGE_FILE_MACHINE_UNKNOWN = 0,
    IMAGE_FILE_MACHINE_AM33  = 0x1d3,
    IMAGE_FILE_MACHINE_AMD64  = 0x8664,
    IMAGE_FILE_MACHINE_ARM = 0x1c0,
    IMAGE_FILE_MACHINE_ARM64 = 0xaa64,
    IMAGE_FILE_MACHINE_ARMNT = 0x1c4,
    IMAGE_FILE_MACHINE_EBC = 0xebc,
    IMAGE_FILE_MACHINE_I386 = 0x14c,
    IMAGE_FILE_MACHINE_IA64 = 0x200,
    IMAGE_FILE_MACHINE_M32R = 0x9041,
    IMAGE_FILE_MACHINE_MIPS16 = 0x266,
    IMAGE_FILE_MACHINE_MIPSFPU = 0x366,
    IMAGE_FILE_MACHINE_MIPSFPU16 = 0x466,
    IMAGE_FILE_MACHINE_POWERPC = 0x1f0,
    IMAGE_FILE_MACHINE_POWERPCFP = 0x1f1,
    IMAGE_FILE_MACHINE_R4000 = 0x166,
    IMAGE_FILE_MACHINE_RISCV32 = 0x5032,
    IMAGE_FILE_MACHINE_RISCV64 = 0x5064,
    IMAGE_FILE_MACHINE_RISCV128 = 0x5128,
    IMAGE_FILE_MACHINE_SH3 = 0x1a2,
    IMAGE_FILE_MACHINE_SH3DSP = 0x1a3,
    IMAGE_FILE_MACHINE_SH4 = 0x1a6,
    IMAGE_FILE_MACHINE_SH5 = 0x1a8,
    IMAGE_FILE_MACHINE_THUMB = 0x1c2,
    IMAGE_FILE_MACHINE_WCEMIPSV2 = 0x169
}

enum CoffCharacteristics : ushort
{
    IMAGE_FILE_RELOCS_STRIPPED = 0x0001,
    IMAGE_FILE_EXECUTABLE_IMAGE = 0x0002,
    IMAGE_FILE_LINE_NUMS_STRIPPED = 0x0004,
    IMAGE_FILE_LOCAL_SYMS_STRIPPED = 0x0008,
    IMAGE_FILE_AGGRESSIVE_WS_TRIM = 0x0010,
    IMAGE_FILE_LARGE_ADDRESS_AWARE = 0x0020,
    IMAGE_FILE_BYTES_REVERSED_LO = 0x0080,
    IMAGE_FILE_32BIT_MACHINE = 0x0100,
    IMAGE_FILE_DEBUG_STRIPPED = 0x0200,
    IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP = 0x0400,
    IMAGE_FILE_NET_RUN_FROM_SWAP = 0x0800,
    IMAGE_FILE_SYSTEM = 0x1000,
    IMAGE_FILE_DLL = 0x2000,
    IMAGE_FILE_UP_SYSTEM_ONLY = 0x4000,
    IMAGE_FILE_BYTES_REVERSED_HI = 0x8000,
}

enum CoffPeSubsystem : ushort
{
    IMAGE_SUBSYSTEM_UNKNOWN = 0,
    IMAGE_SUBSYSTEM_NATIVE = 1,
    IMAGE_SUBSYSTEM_WINDOWS_GUI = 2,
    IMAGE_SUBSYSTEM_WINDOWS_CUI = 3,
    IMAGE_SUBSYSTEM_OS2_CUI = 5,
    IMAGE_SUBSYSTEM_POSIX_CUI = 7,
    IMAGE_SUBSYSTEM_NATIVE_WINDOWS = 8,
    IMAGE_SUBSYSTEM_WINDOWS_CE_GUI = 9,
    IMAGE_SUBSYSTEM_EFI_APPLICATION = 10,
    IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER = 11,
    IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER = 12,
    IMAGE_SUBSYSTEM_EFI_ROM = 13,
    IMAGE_SUBSYSTEM_XBOX = 14,
    IMAGE_SUBSYSTEM_WINDOWS_BOOT_APPLICATION = 16,
}

enum CoffPeDllCharacteristics : ushort
{
    IMAGE_DLLCHARACTERISTICS_HIGH_ENTROPY_VA = 0x0020,
    IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE = 0x0040,
    IMAGE_DLLCHARACTERISTICS_FORCE_INTEGRITY = 0x0080,
    IMAGE_DLLCHARACTERISTICS_NX_COMPAT = 0x0100,
    IMAGE_DLLCHARACTERISTICS_NO_ISOLATION = 0x0200,
    IMAGE_DLLCHARACTERISTICS_NO_SEH = 0x0400,
    IMAGE_DLLCHARACTERISTICS_NO_BIND = 0x0800,
    IMAGE_DLLCHARACTERISTICS_APPCONTAINER = 0x1000,
    IMAGE_DLLCHARACTERISTICS_WDM_DRIVER = 0x2000,
    IMAGE_DLLCHARACTERISTICS_GUARD_CF = 0x4000,
    IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE = 0x8000,
}

enum CoffOptionalHeaderMagic : ushort
{
    PE32     = 0x10B,
    PE32Plus = 0x20B
}

enum CoffSectionTableCharacteristics : uint
{
    IMAGE_SCN_TYPE_NO_PAD = 0x00000008,
    IMAGE_SCN_CNT_CODE = 0x00000020,
    IMAGE_SCN_CNT_INITIALIZED_DATA = 0x00000040,
    IMAGE_SCN_CNT_UNINITIALIZED_DATA = 0x00000080,
    IMAGE_SCN_LNK_OTHER = 0x00000100,
    IMAGE_SCN_LNK_INFO = 0x00000200,
    IMAGE_SCN_LNK_REMOVE = 0x00000800,
    IMAGE_SCN_LNK_COMDAT = 0x00001000,
    IMAGE_SCN_GPREL = 0x00008000,
    IMAGE_SCN_MEM_PURGEABLE = 0x00020000,
    IMAGE_SCN_MEM_16BIT = 0x00020000,
    IMAGE_SCN_MEM_LOCKED = 0x00040000,
    IMAGE_SCN_MEM_PRELOAD = 0x00080000,
    IMAGE_SCN_ALIGN_1BYTES = 0x00100000,
    IMAGE_SCN_ALIGN_2BYTES = 0x00200000,
    IMAGE_SCN_ALIGN_4BYTES = 0x00300000,
    IMAGE_SCN_ALIGN_8BYTES = 0x00400000,
    IMAGE_SCN_ALIGN_16BYTES = 0x00500000,
    IMAGE_SCN_ALIGN_32BYTES = 0x00600000,
    IMAGE_SCN_ALIGN_64BYTES = 0x00700000,
    IMAGE_SCN_ALIGN_128BYTES = 0x00800000,
    IMAGE_SCN_ALIGN_256BYTES = 0x00900000,
    IMAGE_SCN_ALIGN_512BYTES = 0x00A00000,
    IMAGE_SCN_ALIGN_1024BYTES = 0x00B00000,
    IMAGE_SCN_ALIGN_2048BYTES = 0x00C00000,
    IMAGE_SCN_ALIGN_4096BYTES = 0x00D00000,
    IMAGE_SCN_ALIGN_8192BYTES = 0x00E00000,
    IMAGE_SCN_LNK_NRELOC_OVFL = 0x01000000,
    IMAGE_SCN_MEM_DISCARDABLE = 0x02000000,
    IMAGE_SCN_MEM_NOT_CACHED = 0x04000000,
    IMAGE_SCN_MEM_NOT_PAGED = 0x08000000,
    IMAGE_SCN_MEM_SHARED = 0x10000000,
    IMAGE_SCN_MEM_EXECUTE = 0x20000000,
    IMAGE_SCN_MEM_READ = 0x40000000,
    IMAGE_SCN_MEM_WRITE = 0x80000000,
}

struct CoffPe
{
    DosHeader dosHeader;
    CoffHeader coffHeader;
    CoffOptionalHeader optionalHeader;
    Shared!(Array!CoffSectionTable) sectionTables;

    // D goes "grrr" sometimes.
    @nogc nothrow
    this(scope ref return typeof(this) copy)
    {
        this.dosHeader = copy.dosHeader;
        this.coffHeader = copy.coffHeader;
        this.optionalHeader = copy.optionalHeader;
        this.sectionTables.__ctor(copy.sectionTables);
    }
}

struct DosHeader
{
    ushort magic;
    ushort[29] reserved;
    uint newExeHeaderPtr;
}
static assert(DosHeader.sizeof == 64);

struct CoffHeader
{
    char[4] magic;
    CoffMachineType machine;
    ushort sectionCount;
    uint timestamp;
    uint symbolTablePtr_deprecated;
    uint numberOfSymbolTable_deprecated;
    ushort sizeOfOptionalHeader;
    CoffCharacteristics characteristics;
}
static assert(CoffHeader.sizeof == 24);

struct CoffOptionalHeader
{
    CoffStandardFields coffFields;
    CoffPeFields peFields;
    CoffPeDataDirectories peDataDirectories;
}

struct CoffStandardFields
{
    CoffOptionalHeaderMagic magic;
    ubyte linkerMajor;
    ubyte linkerMinor;
    uint sizeOfCode; // Sum of all sections
    uint sizeOfInitialisedData; // .data
    uint sizeOfUninitialisedData; // .bss
    uint entryPointRvaPtr;
    uint baseOfCodeRvaPtr;
    uint baseOfDataRvaPtr; // PE32 ONLY!
}
static assert(CoffStandardFields.sizeof == 28);

struct CoffPeFields
{
    ulong imageBase;
    uint sectionAlignment;
    uint fileAlignment;
    ushort osMajor;
    ushort osMinor;
    ushort imageMajor;
    ushort imageMinor;
    ushort subsystemMajor;
    ushort subsytemMinor;
    uint _;
    uint sizeOfImage;
    uint sizeOfHeaders;
    uint checksum;
    CoffPeSubsystem subsystem;
    CoffPeDllCharacteristics dllCharacteristics;
    ulong sizeOfStackReserve;
    ulong sizeOfStackCommit;
    ulong sizeOfHeapReserve;
    ulong sizeOfHeapCommit;
    uint loaderFlags;
    uint numberOfRvaAndSizes;
}
static assert(CoffPeFields.sizeof == 88);

struct CoffPeDataDirectory
{
    uint tableRvaPtr;
    uint size;
}

struct CoffPeDataDirectories
{
    CoffPeDataDirectory exportTable;
    CoffPeDataDirectory importTable;
    CoffPeDataDirectory resourceTable;
    CoffPeDataDirectory exceptionTable;
    CoffPeDataDirectory certificateTable;
    CoffPeDataDirectory baseRelocationTable;
    CoffPeDataDirectory debug_;
    CoffPeDataDirectory architecture;
    CoffPeDataDirectory globalPtr;
    CoffPeDataDirectory tlsTable;
    CoffPeDataDirectory loadConfigTable;
    CoffPeDataDirectory boundImport;
    CoffPeDataDirectory importAddressTable;
    CoffPeDataDirectory delayImportDescriptor;
    CoffPeDataDirectory clrRuntimeHeader;
    CoffPeDataDirectory reservedMustBeZeroWinkyFaceSmileBlush;
}

struct CoffSectionTable
{
    char[8] name;
    uint virtualSize;
    uint virtualAddress;
    uint sizeOfRawData;
    uint pointerToRawData;
    uint pointerToRelocations;
    uint pointerToLineNumbers;
    ushort numberOfRelocations;
    ushort numberOfLineNumbers;
    CoffSectionTableCharacteristics characteristics;
}

SimpleResult!CoffPe coffpeParseHeader(const ubyte[] data)
{
    import libd.io.memory;

    CoffPe pe;
    auto stream = MemoryReaderStream(data);

    auto result = stream.read((&pe.dosHeader)[0..1]);
    if(!result.isValid)                         return typeof(return)(result.error);
    if(result.value != DosHeader.sizeof)        return typeof(return)(raise("Unexpected EOF when reading DOS header"));
    if(pe.dosHeader.magic != DOS_HEADER_MAGIC)  return typeof(return)(raise("Invalid DOS magic number"));

    stream.setPosition(pe.dosHeader.newExeHeaderPtr).assumeValid;
    result = stream.read((&pe.coffHeader)[0..1]);
    if(!result.isValid)                             return typeof(return)(result.error);
    if(result.value != CoffHeader.sizeof)           return typeof(return)(raise("Unexpected EOF when reading COFF header"));
    if(pe.coffHeader.magic != COFF_HEADER_MAGIC)    return typeof(return)(raise("Invalid COFF magic number"));

    if(pe.coffHeader.sizeOfOptionalHeader)
    {
        ubyte[CoffStandardFields.sizeof] standardFieldsBuffer; // this has a dynamic size depending on optional header type
        scope asStandardFields = cast(CoffStandardFields*)standardFieldsBuffer.ptr;
        stream.read(standardFieldsBuffer[0..2]); // read magic

        auto size = (CoffStandardFields.sizeof - 2) - (
            asStandardFields.magic == CoffOptionalHeaderMagic.PE32
            ? 0
            : 4
        );
        assert(asStandardFields.magic == CoffOptionalHeaderMagic.PE32Plus, "TODO");

        result = stream.read(standardFieldsBuffer[2..2+size]);
        if(!result.isValid)         return typeof(return)(result.error);
        if(result.value != size)    return typeof(return)(raise("Unexpected EOF when reading COFF standard fields"));

        pe.optionalHeader.coffFields = *asStandardFields;

        result = stream.read((&pe.optionalHeader.peFields)[0..1]);
        if(!result.isValid)                         return typeof(return)(result.error);
        if(result.value != CoffPeFields.sizeof)     return typeof(return)(raise("Unexpected EOF when reading COFF PE fields"));

        // again, this is dynamically sized
        const directories = pe.optionalHeader.peFields.numberOfRvaAndSizes;
        const dirSize = directories * CoffPeDataDirectory.sizeof;
        const maxDirSize = CoffPeDataDirectories.sizeof;
        ubyte[maxDirSize] dirBuffer;
        scope asDataDirectories = cast(CoffPeDataDirectories*)dirBuffer.ptr;

        result = stream.read(dirBuffer[0..dirSize]);
        if(!result.isValid)             return typeof(return)(result.error);
        if(result.value != dirSize)     return typeof(return)(raise("Unexpected EOF when reading COFF PE data directories"));

        pe.optionalHeader.peDataDirectories = *asDataDirectories;
    }

    pe.sectionTables = makeShared(Array!CoffSectionTable.init);
    auto tables = pe.sectionTables.ptrUnsafe;
    tables.length = pe.coffHeader.sectionCount;

    foreach(i, ref CoffSectionTable table; tables.range)
    {
        result = stream.read((&table)[0..1]);
        if(!result.isValid)                         return typeof(return)(result.error);
        if(result.value != CoffSectionTable.sizeof) return typeof(return)(raise("Unexpected EOF when reading COFF section table"));
    }

    return typeof(return)(pe);
}