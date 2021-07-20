module object;

// Reminder: my only target is x86_64 
public import runtime.primitives.equality : __equals;
public import runtime.primitives.memory : _memset32;
public import runtime.entrypoint : _d_cmain;

public import libd.datastructures.string, libd.util.errorhandling;

alias string    = immutable(char)[];
alias bcstring  = const(char)[];
alias size_t    = ulong;
alias ptrdiff_t = long;

extern(C) void _d_assert(const char[] message, uint line)
{
}

extern(C) void _d_assertp()
{
}

extern(C) void _assert(char*, char*, uint)
{
    
}