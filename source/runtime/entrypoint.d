module runtime.entrypoint;

import libd.datastructures.array;

__gshared Array!bcstring g_programArgs;

template _d_cmain()
{
    import runtime.entrypoint : g_programArgs, _d_preInit, _d_parseArgs;

    extern(C)
    {
        int _Dmain(char[][] args);

        int mainImpl(int argc, char **argv)
        {
            import runtime.primitives.tls;
            _d_preInit();
            _d_parseArgs();
            const exit = _Dmain(null);

            version(Windows)
            {
                import runtime.system.windows;
                ExitProcess(exit); // Some winapi functions sneakily spawn extra threads.
                                   // This causes the app to sometimes hang.
                                   // ExitProcess cleans things up properly, so we're not left hanging.
            }

            assert(false);
        }

        version(Windows)
        {
            version(LDC)
            {
                int wmain(int argc, char **argv)
                {
                    return mainImpl(argc, argv);
                }
            }
            else
            {
                int main(int argc, char **argv)
                {
                    return mainImpl(argc, argv);
                }
            }
        }
    }
}

void _d_preInit()
{
    import libd.util.cpuid, runtime.dynamicfuncs, libd.console.io;
    cpuidInit();
    _d_dynamicFuncsInit();
    _d_console_io_init();
}

void _d_parseArgs()
{
    import runtime.system.windows, runtime.dynamicfuncs;

    version(Windows)
    {
        auto commandLinePtr = GetCommandLineA();
        auto commandLineSlice = commandLinePtr[0..strlen(commandLinePtr)];
        
        size_t start = 0;
        bool quoteMode = false;
        for(size_t i = 0; i < commandLineSlice.length; i++)
        {
            const ch = commandLineSlice[i];
            
            if(!quoteMode && i > start && (ch == ' ' || ch == '\t' || ch == '\n'))
            {
                g_programArgs.put(commandLineSlice[start..i]);
                start = i + 1;
            }
            else if(ch == '"')
            {
                if(!quoteMode)
                {
                    quoteMode = true;
                    start = i+1;
                }
                else
                {
                    quoteMode = false;
                    g_programArgs.put(commandLineSlice[start..i]);
                    start = i + 2;
                }
            }
        }
    }
}