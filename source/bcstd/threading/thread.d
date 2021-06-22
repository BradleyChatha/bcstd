module bcstd.threading.thread;

public import core.time;
import bcstd.datastructures.hashstuff, bcstd.util.errorhandling;
import bcstd.threading.locks;

version(Windows)
{
    import core.sys.windows.windows;

    alias ThreadHandle = HANDLE;
    alias ThreadId     = DWORD;
    alias TlsHandle    = DWORD;
}
else static assert(false, "TODO Posix");

// private __gshared Lockable!(RobinHoodHashMap!(ThreadId, ThreadStateInfo)) g_threadStates;

// I'll add this all back in if I ever actually need it.
// Which I probably will once we're in Unix land.
// private struct ThreadStateInfo
// {
//     ThreadHandle handle;
// }

// You know, these parts of the Windows API I've been touching aren't actually all that bad.
// It has really great documentation, and sort of "just works" most of the time. Most. Of. The. Time.
struct Thread
{
    @nogc nothrow:

    @disable this(this){}

    private ThreadHandle _handle = INVALID_HANDLE_VALUE;
    private ThreadId     _id;

    ~this()
    {
        closeThread(this);
    }

    bool isAlive()
    {
        return isThreadAlive(this);
    }

    void join(Duration timeout = INFINITE.msecs)
    {
        return joinSingleThread(this, timeout);
    }
}

Thread runThread(ContextT)(SimpleResult!void function(ContextT context) entry, ContextT context)
{
    return createThreadWithUserContext(entry, context);
}

private @nogc nothrow:

extern(C) void rt_moduleTlsCtor();
extern(C) void rt_moduleTlsDtor();

version(Windows)
{
    public void sleep(Duration dur)
    {
        if(dur.isNegative)
            return;
        Sleep(cast(uint)dur.total!"msecs");
    }

    Thread createThreadWithUserContext(ContextT)(SimpleResult!void function(ContextT context) entry, ContextT context)
    {
        static struct ThreadInfo
        {
            ContextT context;
            typeof(entry) entryFunc;
            LockBusyCas threadReadySignal;
        }

        extern(Windows) static DWORD realEntry(void* ptr)
        {
            import bcstd.object;

            auto info        = cast(ThreadInfo*)ptr;
            auto realFunc    = info.entryFunc;
            auto realContext = info.context;
            info.threadReadySignal.unlock(); // info has been copied, allow the parent thread to continue.
            info = null;

            rt_moduleTlsCtor();
            scope(exit) rt_moduleTlsDtor();
            
            auto result = realFunc(realContext);
            if(!result.isValid)
            {
                displayError(result.error);
                return 1;
            }
            return 0;
        }
        auto info = ThreadInfo(context, entry);
        info.threadReadySignal.lock(); // Thread will unlock this once it's read the data.

        DWORD id;
        auto handle = CreateThread(
            null,
            0,
            &realEntry,
            &info,
            0x00010000, // STACK_SIZE_PARAM_IS_A_RESERVATION
            &id
        );

        //g_threadStates.access((ref hashmap) { hashmap.put(id, ThreadStateInfo(handle)); });

        info.threadReadySignal.lock(); // Wait for the thread to unlock it - shouldn't take _too_ long hence why I'm using a busy wait.
        return Thread(handle, id);
    }

    void closeThread(ref Thread thread)
    {
        if(thread._handle != INVALID_HANDLE_VALUE)
        {
            if(!CloseHandle(thread._handle)) // Note: This doesn't actually destroy the thread, it just closes the handle.
                displayError(raise("Could not destroy my thread handle?"));
        }
    }

    bool isThreadAlive(ref Thread thread)
    {
        return WaitForSingleObject(thread._handle, 0) == WAIT_TIMEOUT;
    }

    void joinSingleThread(ref Thread thread, Duration timeout)
    {
        if(timeout.isNegative)
            timeout = Duration.zero;
        WaitForSingleObject(thread._handle, cast(uint)timeout.total!"msecs");
    }
}

@("Thread - basic thread that does nothing and dies.")
unittest
{
    struct DummyContext{}
    runThread((DummyContext _)
    {
        return SimpleResult!void.init;
    }, DummyContext.init); 
}

@("Thread - thread that returns an error")
unittest
{
    struct DummyContext{}
    runThread((DummyContext _)
    {
        return raise("This is an error").result!void;
    }, DummyContext.init);
}

version(unittest) private int _tlsTest;
@("Thread - TLS")
unittest
{
    _tlsTest = 200;
    auto t = runThread((int num)
    {
        assert(_tlsTest == 0);
        _tlsTest = num;
        assert(_tlsTest == 800);
        return SimpleResult!void.init;
    }, 800);
    assert(_tlsTest == 200);
    t.join();
    assert(_tlsTest == 200);
}