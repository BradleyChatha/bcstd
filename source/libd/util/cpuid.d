module libd.util.cpuid;

// The actual code for calling cpuid, populating the store, etc. are all automatically generated.
// The tools/cpuidgen.d tool uses this file as a model for the generated code.
version(DLIB_GenCpuID){}
else public import libd.util._cpuid;

package struct Bits
{
    uint start;
    uint length;
    string name;

    version(DLIB_GenCpuID)
    {
        uint getMask()
        {
            uint mask;
            foreach(i; 0..this.length)
                mask |= (1 << (this.start + i));
            return mask;
        }

        uint getRightShift()
        {
            return this.start;
        }
    }
}

package struct Bit
{
    uint index;
    string name;
}

package struct CpuIdLeaf
{
    uint eax;
    uint ecx;
}

package struct Store
{
    char[12] idString;
    uint     maxLeaf;

    // EAX=1: Processor Info and Feature Bits
    @(
        CpuIdLeaf(1, 0),
        Bits(0, 4,   "steppingId"),
        Bits(4, 4,   "model"),
        Bits(8, 4,   "familyId"),
        Bits(12, 2,  "processorType"),
        Bits(16, 4,  "extendedModelId"),
        Bits(20, 8,  "extendedFamilyId")
    )
    uint eax1_eax;

    @(
        CpuIdLeaf(1, 0),
        Bits(0, 8, "brandIndex"),
        Bits(8, 8, "clflushLineSize"),
        Bits(16, 8, "maxAddressableIdsForLogicalProcessors"),
        Bits(24, 8, "localApicId")
    )
    uint eax1_ebx;

    @(
        CpuIdLeaf(1, 0),
        Bit(0, "sse3"),             Bit(1, "pclmulqdq"),    Bit(2, "dtest64"),  Bit(3, "monitor"),
        Bit(4, "ds_cpl"),           Bit(5, "vmx"),          Bit(6, "smx"),      Bit(7, "est"),
        Bit(8, "tm2"),              Bit(9, "ssse3"),        Bit(10, "cnxt_id"), Bit(11, "sdbg"),
        Bit(12, "fma"),             Bit(13, "cx16"),        Bit(14, "xtpr"),    Bit(15, "pdcm"),
        Bit(16, "_ax1cx_res1"),     Bit(17, "pcid"),        Bit(18, "dca"),     Bit(19, "sse41"),
        Bit(20, "sse42"),           Bit(21, "x2apic"),      Bit(22, "movbe"),   Bit(23, "popcnt"),
        Bit(24, "tsc_deadline"),    Bit(25, "aes"),         Bit(26, "xsave"),   Bit(27, "osxsave"),
        Bit(28, "avx"),             Bit(29, "f16c"),        Bit(30, "rdrnd"),   Bit(31, "hypervisor"),
    )
    uint eax1_ecx;

    @(
        CpuIdLeaf(1, 0),
        Bit(0, "fpu"),          Bit(1, "vem"),      Bit(2, "de"),           Bit(3, "pse"),
        Bit(4, "tsc"),          Bit(5, "msr"),      Bit(6, "pae"),          Bit(7, "mce"),
        Bit(8, "cx8"),          Bit(9, "apic"),     Bit(10, "_ax1dx_res1"), Bit(11, "sep"),
        Bit(12, "mtrr"),        Bit(13, "pge"),     Bit(14, "mca"),         Bit(15, "cmov"),
        Bit(16, "pat"),         Bit(17, "pse_36"),  Bit(18, "psn"),         Bit(19, "clfsh"),
        Bit(20, "_ax1dx_res2"), Bit(21, "ds"),      Bit(22, "acpi"),        Bit(23, "mmx"),
        Bit(24, "fxsr"),        Bit(25, "sse"),     Bit(26, "sse2"),        Bit(27, "ss"),
        Bit(28, "htt"),         Bit(29, "tm"),      Bit(30, "ia64"),        Bit(31, "pbe"),
    )
    uint eax1_edx;

    @(
        CpuIdLeaf(7, 0),
        Bit(0, "fsgsbase"),     Bit(1, "IA32_TSC_ADJUST"),  Bit(2, "sgx"),              Bit(3, "bmi1"),
        Bit(4, "hle"),          Bit(5, "avx2"),             Bit(6, "FDP_EXCPTN_ONLY"),  Bit(7, "smep"),
        Bit(8, "bmi2"),         Bit(9, "erms"),             Bit(10, "invpcid"),         Bit(11, "rtm"),
        Bit(12, "pqrn"),        Bit(13, "CS_DS_DEPR"),      Bit(14, "mpx"),             Bit(15, "pqe"),
        Bit(16, "avx512_f"),    Bit(17, "avx512_dq"),       Bit(18, "rdseed"),          Bit(19, "adx"),
        Bit(20, "smap"),        Bit(21, "avx512_ifma"),     Bit(22, "pcommit"),         Bit(23, "clflushopt"),
        Bit(24, "clwb"),        Bit(25, "intel_pt"),        Bit(26, "avx512_pf"),       Bit(27, "avx512_er"),
        Bit(28, "avx512_cd"),   Bit(29, "sha"),             Bit(30, "avx512_bw"),       Bit(31, "avx512_vl"),
    )
    uint eax7ecx0_ebx;

    @(
        CpuIdLeaf(7, 0),
        Bit(0, "prefetchwt1"),      Bit(1, "avx512_vbmi"),      Bit(2, "umip"),                 Bit(3, "pku"),
        Bit(4, "ospke"),            Bit(5, "waitpkg"),          Bit(6, "avx512_vbmi2"),         Bit(7, "cet_ss"),
        Bit(8, "gfni"),             Bit(9, "vaes"),             Bit(10, "vpclmulqdq"),          Bit(11, "avx512_vnni"),
        Bit(12, "avx512_bitalg"),   Bit(13, "_ax7cx0cx_res1"),  Bit(14, "avx512_vpopcntdq"),    Bit(15, "_ax7cx0cx_res2"),
        Bit(16, "fiveLevelPaging"),
        Bits(17, 5, "mawau"),       Bit(22, "rdpid"),           Bit(23, "_ax7cx0cx_res3"),
        Bit(24, "_ax7cx0cx_res4"),  Bit(25, "cldemote"),        Bit(26, "_ax7cx0cx_res5"),      Bit(27, "movdiri"),
        Bit(28, "movdir64b"),       Bit(29, "enqcmd"),          Bit(30, "sgx_lc"),              Bit(31, "pks"),
    )
    uint eax7ecx0_ecx;

    @(
        CpuIdLeaf(7, 0),
        Bit(0, "_ax7cx0dx_res1"),       Bit(1, "_ax7cx0dx_res2"),           Bit(2, "avx512_4vnniw"),            Bit(3, "avx512_4fmaps"),
        Bit(4, "fsrm"),                 Bit(5, "_ax7cx0dx_res3"),           Bit(6, "_ax7cx0dx_res4"),           Bit(7, "_ax7cx0dx_res5"),
        Bit(8, "avx512_vp2inersect"),   Bit(9, "SRDBS_CTRL"),               Bit(10, "md_clear"),                Bit(11, "_ax7cx0dx_res6"),
        Bit(12, "_ax7cx0dx_res7"),      Bit(13, "tsx_force_abort"),         Bit(14, "SERIALIZE"),               Bit(15, "Hybrid"),
        Bit(16, "TSXLDTRK"),            Bit(17, "_ax7cx0dx_res8"),          Bit(18, "pconfig"),                 Bit(19, "lbr"),
        Bit(20, "cet_ibt"),             Bit(21, "_ax7cx0dx_res9"),          Bit(22, "amx_bf16"),                Bit(23, "AVX512_FP16"),
        Bit(24, "amx_tile"),            Bit(25, "amx_int8"),                Bit(26, "spec_ctrl"),               Bit(27, "stibp"),
        Bit(28, "L1D_FLUSH"),           Bit(29, "IA32_ARCH_CAPABILITIES"),  Bit(30, "IA32_CORE_CAPABILITIES"),  Bit(31, "ssbd"),
    )
    uint eax7ecx0_edx;
}

package __gshared Store g_cpuidStore;
extern(C) void cpuidPopulateStore(Store*);

version(DLIB_GenCpuID)
{
    // Allow cpuidgen to access priate types.
    alias BitsUda = Bits;
    alias BitUda = Bit;
    alias CpuStore = Store;
    alias LeafUda = CpuIdLeaf;

    void cpuidInit()
    {
    }
}
else
{
    void cpuidInit()
    {
        cpuidPopulateStore(&g_cpuidStore);
    }
}