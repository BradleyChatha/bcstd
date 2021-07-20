module runtime.entrypoint;

template _d_cmain()
{
    void _d_preInit()
    {
        import libd.util.cpuid, runtime.dynamicfuncs, libd.console.io;
        cpuidInit();
        _d_dynamicFuncsInit();
        _d_console_io_init();
    }

    extern(C)
    {
        int _Dmain(char[][] args);

        int main(int argc, char **argv)
        {
            import runtime.primitives.tls;
            _d_preInit();
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
    }
}