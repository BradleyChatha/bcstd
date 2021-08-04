module runtime.system.posix.posix_;

ushort octal(int octal) nothrow @nogc
{
    ushort result;

    result += octal % 10;
    octal /= 10;
    result += 8 * (octal % 10);
    octal /= 10;
    result += (8 * 8) * (octal % 10);
    octal /= 10;
    result += (8 * 8 * 8) * (octal % 10);
    octal /= 10;
    result += (8 * 8 * 8 * 8) * (octal % 10);
    octal /= 10;
    result += (8 * 8 * 8 * 8 * 8) * (octal % 10);
    octal /= 10;
    result += (8 * 8 * 8 * 8 * 8 * 8) * (octal % 10);
    octal /= 10;
    result += (8 * 8 * 8 *8 * 8 * 8 * 8) * (octal % 10);
    octal /= 10;

    assert(octal == 0);

    return result;
}
@("octal")
unittest
{
    assert(octal(666) == 0x1B6);
}

version(Posix) extern(C) nothrow @nogc:

enum 
{
    PROT_NONE = 0,
    PROT_READ = 1,
    PROT_WRITE = 2,
    PROT_EXEC = 4,
}

enum 
{
    MAP_FILE = 0,
    MAP_SHARED = 1,
    MAP_PRIVATE = 2,
    MAP_TYPE = 0xF,
    MAP_FIXED = 0x10,
    MAP_ANONYMOUS = 0x20,
    MAP_32BIT = 0x40,
    MAP_GROWSDOWN = 0x00100,
    MAP_DENYWRITE = 0x00800,
    MAP_EXECUTABLE = 0x01000,
    MAP_LOCKED = 0x02000,
    MAP_NORESERVE = 0x04000,
    MAP_POPULATE = 0x08000,
    MAP_NONBLOCK = 0x10000,
    MAP_STACK = 0x20000,
}
enum MAP_FAILED = cast(void*)-1;

enum
{
    O_RDONLY    =   0,
    O_WRONLY    =   1,
    O_RDWR      =   2,
    O_CREAT     =   100.octal,
    O_EXCL      =   200.octal,
    O_NOCTTY    =   400.octal,
    O_TRUNC     =   1000.octal,
    O_APPEND    =   2000.octal,
    O_NONBLOCK  =   4000.octal,
    O_NDELAY    =   O_NONBLOCK,
    O_SYNC      =   4010000.octal,
    O_FSYNC     =   O_SYNC,
    O_ASYNC     =   20000.octal,
    O_LARGEFILE =   100000.octal,
    O_DIRECTORY =   200000.octal,
    O_NOFOLLOW  =   400000.octal,
    O_CLOEXEC   =   2000000.octal,
    O_DIRECT    =   40000.octal,
    O_NOATIME   =   1000000.octal,
    O_PATH      =   10000000.octal,
    O_DSYNC     =   10000.octal,
    O_TMPFILE   =   (20000000.octal | O_DIRECTORY),
}

enum
{
    
EPERM =		1,		/* Operation not permitted */
ENOENT =		2,		/* No such file or directory */
ESRCH =		3,		/* No such process */
EINTR =		4,		/* Interrupted system call */
EIO =		5,		/* Input/output error */
ENXIO =		6,		/* Device not configured */
E2BIG =		7,		/* Argument list too long */
ENOEXEC =		8,		/* Exec format error */
EBADF =		9,		/* Bad file descriptor */
ECHILD =		10,		/* No child processes */
EDEADLK =		11,		/* Resource deadlock avoided */
ENOMEM =		12,		/* Cannot allocate memory */
EACCES =		13,		/* Permission denied */
EFAULT =		14,		/* Bad address */
ENOTBLK =		15,		/* Block device required */
EBUSY =		16,		/* Device busy */
EEXIST =		17,		/* File exists */
EXDEV =		18,		/* Cross-device link */
ENODEV =		19,		/* Operation not supported by device */
ENOTDIR =		20,		/* Not a directory */
EISDIR =		21,		/* Is a directory */
EINVAL =		22,		/* Invalid argument */
ENFILE =		23,		/* Too many open files in system */
EMFILE =		24,		/* Too many open files */
ENOTTY =		25,		/* Inappropriate ioctl for device */
ETXTBSY =		26,		/* Text file busy */
EFBIG =		27,		/* File too large */
ENOSPC =		28,		/* No space left on device */
ESPIPE =		29,		/* Illegal seek */
EROFS =		30,		/* Read-only file system */
EMLINK =		31,		/* Too many links */
EPIPE =		32,		/* Broken pipe */
EDOM =		33,		/* Numerical argument out of domain */
ERANGE =		34,		/* Result too large */
EAGAIN =		35,		/* Resource temporarily unavailable */
EWOULDBLOCK =	EAGAIN,		/* Operation would block */
EINPROGRESS =	36,		/* Operation now in progress */
EALREADY =	37,		/* Operation already in progress */
ENOTSOCK =	38,		/* Socket operation on non-socket */
EDESTADDRREQ =	39,		/* Destination address required */
EMSGSIZE =	40,		/* Message too long */
EPROTOTYPE =	41,		/* Protocol wrong type for socket */
ENOPROTOOPT =	42,		/* Protocol not available */
EPROTONOSUPPORT =	43,		/* Protocol not supported */
ESOCKTNOSUPPORT =	44,		/* Socket type not supported */
EOPNOTSUPP =	45,		/* Operation not supported on socket */
EPFNOSUPPORT =	46,		/* Protocol family not supported */
EAFNOSUPPORT =	47,		/* Address family not supported by protocol family */
EADDRINUSE =	48,		/* Address already in use */
EADDRNOTAVAIL =	49,		/* Can't assign requested address */
ENETDOWN =	50,		/* Network is down */
ENETUNREACH =	51,		/* Network is unreachable */
ENETRESET =	52,		/* Network dropped connection on reset */
ECONNABORTED =	53,		/* Software caused connection abort */
ECONNRESET =	54,		/* Connection reset by peer */
ENOBUFS =		55,		/* No buffer space available */
EISCONN =		56,		/* Socket is already connected */
ENOTCONN =	57,		/* Socket is not connected */
ESHUTDOWN =	58,		/* Can't send after socket shutdown */
ETOOMANYREFS =	59,		/* Too many references: can't splice */
ETIMEDOUT =	60,		/* Connection timed out */
ECONNREFUSED =	61,		/* Connection refused */
ELOOP =		62,		/* Too many levels of symbolic links */
ENAMETOOLONG =	63,		/* File name too long */
EHOSTDOWN =	64,		/* Host is down */
EHOSTUNREACH =	65,		/* No route to host */
ENOTEMPTY =	66,		/* Directory not empty */
EPROCLIM =	67,		/* Too many processes */
EUSERS =		68,		/* Too many users */
EDQUOT =		69,		/* Disc quota exceeded */
ESTALE =		70,		/* Stale NFS file handle */
EREMOTE =		71,		/* Too many levels of remote in path */
EBADRPC =		72,		/* RPC struct is bad */
ERPCMISMATCH =	73,		/* RPC version wrong */
EPROGUNAVAIL =	74,		/* RPC prog. not avail */
EPROGMISMATCH =	75,		/* Program version wrong */
EPROCUNAVAIL =	76,		/* Bad procedure for program */
ENOLCK =		77,		/* No locks available */
ENOSYS =		78,		/* Function not implemented */
EFTYPE =		79,		/* Inappropriate file type or format */
}

enum
{
    SEEK_SET = 0,
    SEEK_CUR = 1,
    SEEK_END = 2,
}

enum
{
    F_OK = 0
}

alias umode_t = ushort;
alias ssize_t = long;
alias uint          dev_t;
alias ulong         ino_t;
alias uint         mode_t;
alias int          pid_t;
alias uint          uid_t;
alias uint          gid_t;
alias ulong       nlink_t;
alias long         off_t;
alias long     blksize_t;
alias long      blkcnt_t;
alias long        time_t;

__gshared int g_errno;

struct timespec {
	time_t	tv_sec;		/* seconds */
	long			tv_nsec;	/* nanoseconds */
};

struct stat {
    dev_t     st_dev;         /* ID of device containing file */
    ino_t     st_ino;         /* Inode number */
    mode_t    st_mode;        /* File type and mode */
    nlink_t   st_nlink;       /* Number of hard links */
    uid_t     st_uid;         /* User ID of owner */
    gid_t     st_gid;         /* Group ID of owner */
    dev_t     st_rdev;        /* Device ID (if special file) */
    off_t     st_size;        /* Total size, in bytes */
    blksize_t st_blksize;     /* Block size for filesystem I/O */
    blkcnt_t  st_blocks;      /* Number of 512B blocks allocated */

    /* Since Linux 2.6, the kernel supports nanosecond
        precision for the following timestamp fields.
        For the details before Linux 2.6, see NOTES. */

    timespec st_atim;  /* Time of last access */
    timespec st_mtim;  /* Time of last modification */
    timespec st_ctim;  /* Time of last status change */
};

private immutable setErrnoReturn = q{
    asm @nogc nothrow {
        jnc RETURN;
        neg RAX;
        lea RCX, g_errno;
        mov [RCX], RAX;
        neg RAX;
        RETURN: ret;
    }
};

void* mmap(
    void* addr, 
    ulong len, 
    int prot = PROT_READ | PROT_WRITE, 
    int flags = MAP_PRIVATE | MAP_ANONYMOUS, 
    int fd = -1, 
    int off = 0
)
{
    asm @nogc nothrow 
    {
        naked;
        mov R10, RCX;
        mov RAX, 9;
        syscall;
    }
    mixin(setErrnoReturn);
}

int munmap(void* addr, ulong len)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 11;
        syscall;
    }
    mixin(setErrnoReturn);
}

int open(const char* filename, int flags, umode_t mode)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 2;
        syscall;
    }
    mixin(setErrnoReturn);
}

int close(uint fd)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 3;
        syscall;
    }
    mixin(setErrnoReturn);
}

ssize_t read(int fd, void* buf, size_t count)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 0;
        syscall;
    }
    mixin(setErrnoReturn);
}

ssize_t write(int fd, const void* buf, size_t count)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 1;
        syscall;
    }
    mixin(setErrnoReturn);
}

int fstat(int fd, stat* statbuf)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 5;
        syscall;
    }
    mixin(setErrnoReturn);
}

off_t lseek(int fd, off_t offset, int whence)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 8;
        syscall;
    }
    mixin(setErrnoReturn);
}

int access(const char* filename, int mode)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 21;
        syscall;
    }
    mixin(setErrnoReturn);
}

int unlink(const char* filename)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 87;
        syscall;
    }
    mixin(setErrnoReturn);
}

int rmdir(const char* filename)
{
    asm @nogc nothrow
    {
        naked;
        mov RAX, 84;
        syscall;
    }
    mixin(setErrnoReturn);
}