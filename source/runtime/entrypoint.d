module runtime.entrypoint;

template _d_cmain()
{
    void _d_preInit()
    {
        import libd.util.cpuid, runtime.dynamicfuncs;
        cpuidInit();
        _d_dynamicFuncsInit();
    }

    extern(C)
    {
        int main(int argc, char **argv)
        {
            _d_preInit();
            return -1;
        }
    }
}