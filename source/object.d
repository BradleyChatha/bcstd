module object;

// Reminder: my only target is x86_64 
public import runtime.primitives.equality : __equals;
public import runtime.primitives.memory : _memset32;
public import runtime.primitives.move : __ArrayDtor;
public import runtime.entrypoint : _d_cmain;
public import libd.datastructures.string, libd.datastructures.array, libd.datastructures.hashstuff, libd.util.errorhandling;

extern(C) int _fltused = 0; // not a fucking clue.

alias string    = immutable(char)[];
alias bcstring  = const(char)[];
alias size_t    = ulong;
alias ptrdiff_t = long;

extern(C) void _d_assert(const char[] message, uint line)
{
    assertImpl(String(message), String("Unknown"), line);
}

extern(C) void _d_assertp()
{
    assertImpl(String("Unknown"), String("Unkown"), 0);
}

extern(C) void _assert(char* message, char* file, uint line)
{
    assertImpl(String(message), String(file), line);
}

private void assertImpl(String message, String file, uint line)
{
    version(unittest)
    {
        import libd.testing.runner, libd.async;
        if(!g_testRunnerRunning)
            return;

        taskYieldRaise(BcError(
            file,
            String("Unknown"),
            String("Unknown"),
            line,
            0,
            message
        ));
    }
}