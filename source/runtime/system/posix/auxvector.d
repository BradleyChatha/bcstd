module runtime.system.posix.auxvector;

version(Posix) @nogc nothrow:

enum AT_NULL =   0;	/* end of vector */
enum AT_IGNORE = 1;	/* entry should be ignored */
enum AT_EXECFD = 2;	/* file descriptor of program */
enum AT_PHDR =   3;	/* program headers for program */
enum AT_PHENT =  4;	/* size of program header entry */
enum AT_PHNUM =  5;	/* number of program headers */
enum AT_PAGESZ = 6;	/* system page size */
enum AT_BASE =   7;	/* base address of interpreter */
enum AT_FLAGS =  8;	/* flags */
enum AT_ENTRY =  9;	/* entry point of program */
enum AT_NOTELF = 10;	/* program is not ELF */
enum AT_UID =    11;	/* real uid */
enum AT_EUID =   12;	/* effective uid */
enum AT_GID =    13;	/* real gid */
enum AT_EGID =   14;	/* effective gid */
enum AT_PLATFORM = 15;  /* string identifying CPU for optimizations */
enum AT_HWCAP =  16;    /* arch dependent hints at CPU capabilities */
enum AT_CLKTCK = 17;	/* frequency at which times() increments */
enum AT_SECURE = 23;   /* secure mode boolean */
enum AT_BASE_PLATFORM = 24;	/* string identifying real platform, may*/
enum AT_RANDOM = 25;	/* address of 16 random bytes */
enum AT_HWCAP2 = 26;	/* extension of AT_HWCAP */
enum AT_EXECFN = 31;	/* filename of program */

__gshared uint g_posixPageSize;

struct auxv_t
{
    uint a_type;
    union {
        uint a_val;
    }
}

void _d_loadAuxVector(char** envp)
{
    // mhmm, mhmm, yep, very sensible and logical mr linux.
    while(*envp++ !is null){}

    auto auxp = cast(auxv_t*)envp; // This feels so, so wrong.
    while(auxp.a_type != AT_NULL)
    {
        switch(auxp.a_type)
        {
            case AT_PAGESZ:
                g_posixPageSize = auxp.a_val;
                break;

            default: break;
        }

        auxp += (auxv_t*).sizeof;
    }
}