module runtime.stacktrace;

struct StackTraceInfo
{
    String symbol;
    String file;
    uint line;
    ulong lineAddress;
    ulong symbolAddress;
}

StackTraceInfo[Amount] traceGetStackTrace(size_t Amount)(uint toSkip, out size_t count)
{
    return getStackTraceImpl!Amount(toSkip, count);
}

version(Windows)
{
    StackTraceInfo[Amount] getStackTraceImpl(size_t Amount)(uint toSkip, out size_t count)
    {
        import runtime.system.windows;

        typeof(return) ret;

        g_debugHelp.access((scope ref help)
        {
            // + 4 = __lambda, .access, getStackTraceImpl, traceGetStackTrace
            auto results = help.backtrace!Amount(4 + toSkip, count);
            foreach(i, result; results[0..count])
                ret[i] = StackTraceInfo(result.symbol, result.file, result.line, result.lineAddress, result.symbolAddress);
        });

        return ret;
    }
}