module runtime.system.windows.windows_;

version(Windows):
extern (Windows) @nogc nothrow:

/++ HELPERS ++/
String GetLastErrorAsString()
{
    char[1024] buffer;
    const error = GetLastError();
    const length = FormatMessageA(
        FORMAT_MESSAGE_FROM_SYSTEM,
        null,
        error,
        0,
        buffer.ptr,
        buffer.length,
        null
    );
    return String(buffer[0..length]);
}

/++ stuff to emulate things like _In, _Out, etc ++/
struct _Frees_ptr_opt_{}
struct _In_ {}

/++A bunch of types++/
alias BOOL = int;
alias BOOLEAN = bool;
alias BYTE = ubyte;
alias CCHAR = char; // Technically byte because D chars are UTF8, buuuuut it's super fucking annoying otherwise.
alias CHAR = char;
alias COLORREF = DWORD;
alias DWORD = uint;
alias DWORDLONG = ulong;
alias DWORD_PTR = ULONG_PTR;
alias DWORD32 = uint;
alias DWORD64 = ulong;
alias FLOAT = float;
alias HACCEL = HANDLE;
alias HALF_PTR = uint;
alias HANDLE = PVOID;
alias HBITMAP = HANDLE;
alias HBRUSH = HANDLE;
alias HCOLORSPACE = HANDLE;
alias HCONV = HANDLE;
alias HCONVLIST = HANDLE;
alias HCURSOR = HANDLE;
alias HDC = HANDLE;
alias HDDEDATA = HANDLE;
alias HDESK = HANDLE;
alias HDROP = HANDLE;
alias HDWP = HANDLE;
alias HENHMETAFILE = HANDLE;
alias HFILE = HANDLE;
alias HFONT = HANDLE;
alias HGDIOBJ = HANDLE;
alias HGLOBAL = HANDLE;
alias HHOOK = HANDLE;
alias HICON = HANDLE;
alias HINSTANCE = HANDLE;
alias HKEY = HANDLE;
alias HKL = HANDLE;
alias HLOCAL = HANDLE;
alias HMENU = HANDLE;
alias HMETAFILE = HANDLE;
alias HMODULE = HANDLE;
alias HMONITOR = HANDLE;
alias HPALETTE = HANDLE;
alias HPEN = HANDLE;
alias HRESULT = HANDLE;
alias HRGN = HANDLE;
alias HSRC = HANDLE;
alias HWINSTA = HANDLE;
alias HWND = HANDLE;
alias INT = int;
alias INT_PTR = long;
alias INT8 = byte;
alias INT16 = short;
alias INT32 = int;
alias INT64 = long;
alias LARGE_INTEGER = long;
alias LANGID = WORD;
alias LCID = DWORD;
alias LCTYPE = DWORD;
alias LGRPID = DWORD;
alias LONG = int;
alias LONGLONG = long;
alias LONG_PTR = long;
alias LONG32 = int;
alias LONG64 = long; // Microsoft make no fricking sense man.
alias LPARAM = LONG_PTR;
alias LPBOOL = BOOL*;
alias LPCOLORREF = COLORREF*;
alias LPCSTR = const CHAR*;
alias LPCTSTR = LPCWSTR;
alias LPCVOID = const void*;
alias LPCWSTR = const WCHAR*;
alias LPDWORD = DWORD*;
alias LPHANDLE = HANDLE*;
alias LPINT = INT*;
alias LPLONG = LONG*;
alias LPSTR = CHAR*;
alias LPTSTR = LPWSTR;
alias LPVOID = void*;
alias LPWSTR = WCHAR*;
alias LRESULT = LONG_PTR;
alias PBOOL = BOOL*;
alias PBOOLEAN = BOOLEAN*;
alias PBYTE = BYTE*;
alias PCHAR = CHAR*;
alias PCSTR = const CHAR*;
alias PCTSTR = const LPCWSTR*;
alias PCWSTR = const wchar*;
alias PDWORD = DWORD*;
alias PDWORDLONG = DWORDLONG*;
alias PDWORD_PTR = DWORD_PTR*;
alias PDWORD32 = DWORD32*;
alias PDWORD64 = DWORD64*;
alias PFLOAT = FLOAT*;
alias PHALF_PTR = HALF_PTR*;
alias PHANDLE = HANDLE*;
alias PLARGE_INTEGER = LARGE_INTEGER*;
// todo...
alias PVOID = void*;
alias QWORD = ulong;
alias SHORT = short;
alias SIZE_T = ulong;
alias SSIZE_T = long;
alias UINT = uint;
alias UINT_PTR = ulong;
alias UINT8 = ubyte;
alias UINT16 = ushort;
alias UINT32 = uint;
alias UINT64 = ulong;
alias ULONG = uint;
alias ULONG_PTR = ulong;
alias ULONGLONG = ulong;
alias USHORT = ushort;
alias WCHAR = wchar;
alias WORD = ushort;

alias FARPROC = int function();

enum : DWORD
{
    GENERIC_ALL = 1 << 28,
    GENERIC_EXECUTE = 1 << 29,
    GENERIC_WRITE = 1 << 30,
    GENERIC_READ = 1 << 31
}

/++ liboaderapi.h ++/
alias DLL_DIRECTORY_COOKIE = HANDLE;
enum : DWORD
{
    GET_MODULE_HANDLE_EX_FLAG_PIN = 0x00000001,
    GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = 0x00000002,
    GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS = 0x00000004,

    DONT_RESOLVE_DLL_REFERENCES = 0x00000001,
    LOAD_IGNORE_CODE_AUTHZ_LEVEL = 0x00000010,
    LOAD_LIBRARY_AS_DATAFILE = 0x00000002,
    LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE = 0x00000040,
    LOAD_LIBRARY_AS_IMAGE_RESOURCE = 0x00000020,
    LOAD_LIBRARY_SEARCH_APPLICATION_DIR = 0x00000200,
    LOAD_LIBRARY_SEARCH_DEFAULT_DIRS = 0x00001000,
    LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR = 0x00000100,
    LOAD_LIBRARY_SEARCH_SYSTEM32 = 0x00000800,
    LOAD_LIBRARY_SEARCH_USER_DIRS = 0x00000400,
    LOAD_WITH_ALTERED_SEARCH_PATH = 0x00000008,
    LOAD_LIBRARY_REQUIRE_SIGNED_TARGET = 0x00000080,
    LOAD_LIBRARY_SAFE_CURRENT_DIRS = 0x00002000,
}
DLL_DIRECTORY_COOKIE AddDllDirectory(PCWSTR NewDirectory);
BOOL DisableThreadLibraryCalls(HMODULE hLibModule);
BOOL FreeLibrary(HMODULE hLibModule);
void FreeLibraryAndExitThread(HMODULE hLibModule, DWORD dwExitCode);
DWORD GetModuleFileNameA(HMODULE hModule, LPSTR lpFilename, DWORD nSize);
DWORD GetModuleFileNameW(HMODULE hModule, LPWSTR lpFilename, DWORD nSize);
HMODULE GetModuleHandleA(LPCSTR lpModuleName);
HMODULE GetModuleHandleW(LPCWSTR lpModuleName);
BOOL GetModuleHandleExA(DWORD dwFlags, LPCSTR lpModuleName, HMODULE* phModule);
BOOL GetModuleHandleExW(DWORD dwFlags, LPCWSTR lpModuleName, HMODULE* phModule);
FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);
HMODULE LoadLibraryA(LPCSTR lpLibFileName);
HMODULE LoadLibraryW(LPCWSTR lpLibFileName);
HMODULE LoadLibraryExA(LPCSTR lpLibFileName, HANDLE hFile, DWORD dwFlags);
HMODULE LoadLibraryExW(LPCWSTR lpLibFileName, HANDLE hFile, DWORD dwFlags);
BOOL RemoveDllDirectory(DLL_DIRECTORY_COOKIE Cookie);
BOOL SetDefaultDllDirectories(DWORD DirectoryFlags);

/++ memoryapi.h ++/
enum : DWORD
{
    MEM_COMMIT = 0x00001000,
    MEM_RESERVE = 0x00002000,
    MEM_RESET = 0x00080000,
    MEM_RESET_UNDO = 0x1000000,
    MEM_LARGE_PAGES = 0x20000000,
    MEM_PHYSICAL = 0x00400000,
    MEM_TOP_DOWN = 0x00100000,
    MEM_WRITE_WATCH = 0x00200000,
    MEM_DECOMMIT = 0x00004000,
    MEM_RELEASE = 0x00008000,
    MEM_COALESCE_PLACEHOLDERS = 0x00000001,
    MEM_PRESERVE_PLACEHOLDER = 0x00000002,

    PAGE_EXECUTE = 0x10,
    PAGE_EXECUTE_READ = 0x20,
    PAGE_EXECUTE_READWRITE = 0x40,
    PAGE_EXECUTE_WRITECOPY = 0x80,
    PAGE_NOACCESS = 0x01,
    PAGE_READONLY = 0x02,
    PAGE_READWRITE = 0x04,
    PAGE_WRITECOPY = 0x08,
    PAGE_TARGETS_INVALID = 0x40000000,
    PAGE_TARGETS_NO_UPDATE = 0x40000000,
    PAGE_GUARD = 0x100,
    PAGE_NOCACHE = 0x200,
    PAGE_WRITECOMBINE = 0x400,
}
LPVOID VirtualAlloc(LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
BOOL VirtualFree(LPVOID lpAddress, SIZE_T dwSize, DWORD dwFreeType);
BOOL VirtualProtect(LPVOID lpAddress, SIZE_T dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);

/++ heapapi.h ++/
enum : DWORD
{
    HEAP_NO_SERIALIZE = 0x00000001,
    HEAP_GENERATE_EXCEPTIONS = 0x00000004,
    HEAP_ZERO_MEMORY = 0x00000008,
    HEAP_REALLOC_IN_PLACE_ONLY = 0x00000010,
}
LPVOID HeapAlloc(HANDLE hHeap, DWORD dwFlags, SIZE_T dwBytes);
LPVOID HeapReAlloc(HANDLE hHeap, DWORD dwFlags, @_Frees_ptr_opt_ LPVOID lpMem, SIZE_T dwBytes);
BOOL HeapFree(HANDLE hHeap, DWORD dwFlags, @_Frees_ptr_opt_ LPVOID lpMem);
HANDLE GetProcessHeap();

/++ systeminfoapi.h ++/
// One thing I love about the alias spam is: I can basically just copy-paste shit from MSDN and it'll compile with a few tweaks.
struct SYSTEM_INFO {
    union {
        DWORD dwOemId;
        struct {
            WORD wProcessorArchitecture;
            WORD wReserved;
        }
    }
    DWORD     dwPageSize;
    LPVOID    lpMinimumApplicationAddress;
    LPVOID    lpMaximumApplicationAddress;
    DWORD_PTR dwActiveProcessorMask;
    DWORD     dwNumberOfProcessors;
    DWORD     dwProcessorType;
    DWORD     dwAllocationGranularity;
    WORD      wProcessorLevel;
    WORD      wProcessorRevision;
}
alias LPSYSTEM_INFO = SYSTEM_INFO*;
void GetSystemInfo(LPSYSTEM_INFO lpSystemInfo);

/++ fileapi.h ++/
enum HANDLE INVALID_HANDLE_VALUE = cast(HANDLE)-1;
struct SECURITY_ATTRIBUTES {
    DWORD  nLength;
    LPVOID lpSecurityDescriptor;
    BOOL   bInheritHandle;
}
struct OVERLAPPED {
    ULONG_PTR Internal;
    ULONG_PTR InternalHigh;
    union {
        struct {
        DWORD Offset;
        DWORD OffsetHigh;
        }
        PVOID Pointer;
    }
    HANDLE    hEvent;
}
alias LPSECURITY_ATTRIBUTES = SECURITY_ATTRIBUTES*;
alias LPOVERLAPPED = OVERLAPPED*;
enum : DWORD
{
    FILE_SHARE_DELETE = 0x00000004,
    FILE_SHARE_READ = 0x00000001,
    FILE_SHARE_WRITE = 0x00000002,

    CREATE_ALWAYS = 2,
    CREATE_NEW = 1,
    OPEN_ALWAYS = 4,
    OPEN_EXISTING = 3,
    TRUNCATE_EXISTING = 5,

    FILE_ATTRIBUTE_ARCHIVE = 32,
    FILE_ATTRIBUTE_ENCRYPTED = 16384,
    FILE_ATTRIBUTE_HIDDEN = 2,
    FILE_ATTRIBUTE_NORMAL = 128,
    FILE_ATTRIBUTE_OFFLINE = 4096,
    FILE_ATTRIBUTE_READONLY = 1,
    FILE_ATTRIBUTE_SYSTEM = 4,
    FILE_ATTRIBUTE_TEMPORARY = 256,
    FILE_FLAG_BACKUP_SEMANTICS = 0x02000000,
    FILE_FLAG_DELETE_ON_CLOSE = 0x04000000,
    FILE_FLAG_NO_BUFFERING = 0x20000000,
    FILE_FLAG_OPEN_NO_RECALL = 0x00100000,
    FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000,
    FILE_FLAG_OVERLAPPED = 0x40000000,
    FILE_FLAG_POSIX_SEMANTICS = 0x01000000,
    FILE_FLAG_RANDOM_ACCESS = 0x10000000,
    FILE_FLAG_SESSION_AWARE = 0x00800000,
    FILE_FLAG_SEQUENTIAL_SCAN = 0x08000000,
    FILE_FLAG_WRITE_THROUGH = 0x80000000,
}
HANDLE CreateFileA(
    LPCSTR                lpFileName,
    DWORD                 dwDesiredAccess,
    DWORD                 dwShareMode,
    LPSECURITY_ATTRIBUTES lpSecurityAttributes,
    DWORD                 dwCreationDisposition,
    DWORD                 dwFlagsAndAttributes,
    HANDLE                hTemplateFile
);
BOOL WriteFile(
    HANDLE       hFile,
    LPCVOID      lpBuffer,
    DWORD        nNumberOfBytesToWrite,
    LPDWORD      lpNumberOfBytesWritten,
    LPOVERLAPPED lpOverlapped
);
BOOL GetFileSizeEx(
    HANDLE         hFile,
    PLARGE_INTEGER lpFileSize
);
BOOL SetFilePointerEx(
    HANDLE         hFile,
    LARGE_INTEGER  liDistanceToMove,
    PLARGE_INTEGER lpNewFilePointer,
    DWORD          dwMoveMethod
);
BOOL ReadFile(
    HANDLE       hFile,
    LPVOID       lpBuffer,
    DWORD        nNumberOfBytesToRead,
    LPDWORD      lpNumberOfBytesRead,
    LPOVERLAPPED lpOverlapped
);
BOOL PathFileExistsA(
    LPCSTR pszPath
);
BOOL DeleteFileA(
    LPCSTR lpFileName
);

/++ handleapi.h ++/
BOOL CloseHandle(HANDLE hObject);

/++ errhandlingapi.h ++/
enum : DWORD
{
    ERROR_FILE_NOT_FOUND = 2,
    ERROR_ACCESS_DENIED = 4,
    ERROR_FILE_EXISTS = 80,
    ERROR_ALREADY_EXISTS = 183,
}
DWORD GetLastError();

/++ winbase.h ++/
enum : DWORD
{
    FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100,
    FORMAT_MESSAGE_ARGUMENT_ARRAY = 0x00002000,
    FORMAT_MESSAGE_FROM_HMODULE = 0x00000800,
    FORMAT_MESSAGE_FROM_STRING = 0x00000400,
    FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000,
    FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
}
DWORD FormatMessageA(
    DWORD   dwFlags,
    LPCVOID lpSource,
    DWORD   dwMessageId,
    DWORD   dwLanguageId,
    LPSTR   lpBuffer,
    DWORD   nSize,
    void   *Arguments
);

/++ processthreadsapi.h ++/
void ExitProcess(
    UINT uExitCode
);

/++ console api ++/
enum : DWORD
{
    STD_INPUT_HANDLE = -10,
    STD_OUTPUT_HANDLE = -11,
    STD_ERROR_HANDLE = -12,
}
HANDLE GetStdHandle(
    @_In_ DWORD nStdHandle
);