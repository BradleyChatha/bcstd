module bcstd.object;

import bcstd.threading.locks : LockBusyCas;

alias bcstring = const(char)[];

private __gshared LockBusyCas g_appInitLock;

void bcstdAppInit()
{
    assert(g_appInitLock.tryLock(), "Only a single call to AppInit can be made");
}

void bcstdAppUninit()
{
}