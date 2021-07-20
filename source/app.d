version(Testing)
{
    int main()
    {
        import libd.io, libd.console.io, libd.data.coff_pe, libd.testing;
        import runtime.entrypoint;

        Array!TestCase cases;
        testGetLibdCases(cases);
        testRunner(g_programArgs[0..$], cases);

        return 0;
    }
}