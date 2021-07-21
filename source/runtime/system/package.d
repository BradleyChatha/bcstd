module runtime.system;

public import
    runtime.system.windows;

void _d_init_system()
{
    version(Windows)
    {
        _d_init_dbghlp();
    }
}