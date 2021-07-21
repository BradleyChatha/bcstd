module runtime.system.windows.dbghelp;


version(Windows):
@nogc nothrow:

import libd.threading.locks, runtime.system.windows;

__gshared Lockable!DebugHelp g_debugHelp;

private alias SymInitializeT = extern(Windows) BOOL function(
    HANDLE hProcess,
    PCSTR  UserSearchPath,
    BOOL   fInvadeProcess
);

private alias CaptureStackBackTraceT = extern(Windows) USHORT function(
    @_In_      ULONG  FramesToSkip,
    @_In_      ULONG  FramesToCapture,
    @_Out_     PVOID  *BackTrace,
    @_Out_opt_ PULONG BackTraceHash
);

private alias SymGetLineFromAddr64 = extern(Windows) BOOL function(
    HANDLE           hProcess,
    DWORD64          qwAddr,
    PDWORD           pdwDisplacement,
    PIMAGEHLP_LINE64 Line64
);

private alias SymFromAddrT = extern(Windows) BOOL function(
    HANDLE       hProcess,
    DWORD64      Address,
    PDWORD64     Displacement,
    PSYMBOL_INFO Symbol
);

private alias SymSetOptions = extern(Windows) DWORD function(
    DWORD SymOptions
);

private alias SymGetOptions = extern(Windows) DWORD function();

private struct IMAGEHLP_LINE64 {
    DWORD   SizeOfStruct;
    PVOID   Key;
    DWORD   LineNumber;
    PCHAR   FileName;
    DWORD64 Address;
}
private alias PIMAGEHLP_LINE64 = IMAGEHLP_LINE64*;

private struct SYMBOL_INFO {
    ULONG   SizeOfStruct;
    ULONG   TypeIndex;
    ULONG64[2] Reserved;
    ULONG   Index;
    ULONG   Size;
    ULONG64 ModBase;
    ULONG   Flags;
    ULONG64 Value;
    ULONG64 Address;
    ULONG   Register;
    ULONG   Scope;
    ULONG   Tag;
    ULONG   NameLen;
    ULONG   MaxNameLen;
    CHAR[1]    Name;
}
alias PSYMBOL_INFO = SYMBOL_INFO*;

struct DebugHelpStackTrace
{
    String symbol;
    String file;
    ulong symbolAddress;
    uint line;
    ulong lineAddress;
}

private struct DebugHelp
{
    enum MAX_SYMBOL_NAME = 1024; // D symbols are about as long as the average node_modules list.

    bool isAvailable;
    SymInitializeT SymInitialize;
    CaptureStackBackTraceT CaptureStackBackTrace;
    SymGetLineFromAddr64 SymGetLineFromAddr;
    SymFromAddrT SymFromAddr;

    @nogc nothrow:

    DebugHelpStackTrace[Amount] backtrace(size_t Amount)(ULONG framesToSkip, out size_t count)
    {
        typeof(return) traces;

        void*[Amount] frames;
        count = this.CaptureStackBackTrace(
            framesToSkip+1,
            Amount,
            frames.ptr,
            null
        );

        ubyte[SYMBOL_INFO.sizeof + MAX_SYMBOL_NAME] buffer;
        auto asInfo = cast(PSYMBOL_INFO)buffer.ptr;
        asInfo.SizeOfStruct = SYMBOL_INFO.sizeof;
        asInfo.MaxNameLen = MAX_SYMBOL_NAME;

        auto process = GetCurrentProcess();

        foreach(i; 0..count)
        {
            const address = frames[i];
            const symFound = this.SymFromAddr(
                process,
                cast(DWORD64)address,
                null,
                asInfo
            );

            if(!symFound)
            {
                traces[i] = DebugHelpStackTrace(
                    String("[COULD NOT FIND]"),
                    String("???"),
                    0,
                    0,
                    0,
                );
                continue;
            }

            IMAGEHLP_LINE64 line;
            line.SizeOfStruct = IMAGEHLP_LINE64.sizeof;

            DWORD thisParamIsntOptionalBtw;            
            const lineFound = this.SymGetLineFromAddr(
                process, 
                cast(DWORD64)address, 
                &thisParamIsntOptionalBtw, 
                &line
            );

            version(unittest)
            {
                if(!lineFound && GetLastError() != 487) // invalid address
                {
                    import libd.console;
                    consoleWriteln(
                        "[unittest-only][libd-runtime] Could not find line information: "
                        .ansi.fg(Ansi4BitColour.red),
                        asInfo.Name.ptr[0..asInfo.NameLen],
                        " -> ",
                        GetLastError(),
                        ' ',
                        GetLastErrorAsString()
                    );
                }
            }

            traces[i] = DebugHelpStackTrace(
                String(asInfo.Name.ptr[0..asInfo.NameLen]),
                String(line.FileName),
                asInfo.Address,
                line.LineNumber,
                line.Address,
            );
        }
        return traces;
    }
}

@nogc nothrow
void _d_init_dbghlp()
{
    import libd.console;

    auto dll = LoadLibraryA("dbghelp.dll");
    auto nt  = LoadLibraryA("NtDll.dll");
    if(!dll)
    {
        debug consoleWriteln(
            "[debug-only][libd-runtime] Could not load dbghelp.dll - Stack trace disabled."
            .ansi.fg(Ansi4BitColour.yellow)
        );
        return;
    }
    if(!nt)
    {
        debug consoleWriteln(
            "[debug-only][libd-runtime] Could not load NtDll.dll - Stack trace disabled."
            .ansi.fg(Ansi4BitColour.yellow)
        );
        return;
    }

    g_debugHelp.access((scope ref help)
    {
        auto process = GetCurrentProcess();
        
        static T loadFunc(T)(HMODULE dll, LPCSTR name, ref bool wasFailure)
        {
            auto ptr = cast(T)GetProcAddress(dll, name);
            if(ptr is null)
            {
                wasFailure = true;
                debug consoleWriteln(
                    "[debug-only][libd-runtime] Could not load dbghelp.dll function - Stack trace disabled: "
                    .ansi.fg(Ansi4BitColour.yellow),
                    String(name)
                );
            }

            return ptr;
        }

        bool wasFailure;
        auto symInit  = loadFunc!SymInitializeT         (dll, "SymInitialize", wasFailure);
        auto capTrace = loadFunc!CaptureStackBackTraceT (nt, "RtlCaptureStackBackTrace", wasFailure);
        auto getLine  = loadFunc!SymGetLineFromAddr64   (dll, "SymGetLineFromAddr64", wasFailure);
        auto fromAddr = loadFunc!SymFromAddrT           (dll, "SymFromAddr", wasFailure);
        auto setOpt   = loadFunc!SymSetOptions          (dll, "SymSetOptions", wasFailure);
        auto getOpt   = loadFunc!SymGetOptions          (dll, "SymGetOptions", wasFailure);

        if(wasFailure)
            return;

        help.SymInitialize = symInit;
        help.CaptureStackBackTrace = capTrace;
        help.SymGetLineFromAddr = getLine;
        help.SymFromAddr = fromAddr;

        enum SYMOPT_FAIL_CRITICAL_ERRORS = 0x00000200;
        enum SYMOPT_LOAD_LINES = 0x00000010;
        enum SYMOPT_NO_PROMPTS = 0x00080000;
        enum SYMOPT_UNDNAME = 0x00000002;
        enum SYMOPT_DEFERRED_LOADS = 0x00000004;
        const currOpt = getOpt();
        setOpt(
            currOpt
            | SYMOPT_FAIL_CRITICAL_ERRORS
            | SYMOPT_LOAD_LINES
            | SYMOPT_NO_PROMPTS
            | SYMOPT_UNDNAME
            | SYMOPT_DEFERRED_LOADS
        );

        if(!help.SymInitialize(process, null, true))
        {
            debug consoleWriteln(
                "[debug-only][libd-runtime] SymInitialize failed - Stack trace disabled"
                .ansi.fg(Ansi4BitColour.yellow)
            );
            return;
        }

        help.isAvailable = true;
    });

    return;
}