module bcstd.threading.thread;

public import core.time;
import bcstd.datastructures.hashstuff, bcstd.datastructures.array, bcstd.util.errorhandling;
import bcstd.threading.locks, bcstd.threading.canceltoken;

version(Windows)
{
    import core.sys.windows.windows;

    alias ThreadHandle = HANDLE;
    alias ThreadId     = DWORD;
    alias TlsHandle    = DWORD;
}
else static assert(false, "TODO Posix");

private __gshared Lockable!(RobinHoodHashMap!(ThreadId, ThreadStateInfo)) g_threadStates;

private struct ThreadStateInfo
{
    CancelToken appClosingToken;
    ThreadHandle handle;
}

// You know, these parts of the Windows API I've been touching aren't actually all that bad.
// It has really great documentation, and sort of "just works" most of the time. Most. Of. The. Time.
struct Thread
{
    @nogc nothrow:

    private ThreadHandle _handle = INVALID_HANDLE_VALUE;
    private ThreadId _id;

    bool isAlive()
    {
        return isThreadAlive(this);
    }

    void join(Duration timeout = INFINITE.msecs)
    {
        return joinSingleThread(this, timeout);
    }
}

Thread threadRun(ContextT)(SimpleResult!void function(ContextT context) entry, ContextT context)
{
    return createThreadWithUserContext(entry, context);
}

bool threadIsCanceled()
{
    auto result = false;
    g_threadStates.access((ref hashmap)
    {
        result = hashmap.getPtrUnsafeAt(g_thisThreadId).appClosingToken.isCancelRequested;
    });

    return result;
}

package(bcstd) @nogc nothrow:

void threadingOnAppClosing()
{
    Array!ThreadHandle threads;
    g_threadStates.access((ref hashmap)
    {
        foreach(kvp; hashmap.range)
        {
            kvp.value.appClosingToken.cancel();
            threads.put(kvp.value.handle);
        }
    });

    // TODO: Maybe allow threads to specify if they're a foreground or a background thread, and only join on the foreground ones.
    joinMultipleThreads(threads[], 60.seconds); // After a minute, allow the program to close, forcing the threads to finish one way or another.
}

private @nogc nothrow:

ThreadId g_thisThreadId;

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

            const id = GetCurrentThreadId();
            scope(exit)
            {
                g_threadStates.access((ref hashmap)
                {
                    ThreadStateInfo info;
                    hashmap.removeAt(cast(ThreadId)id, info);
                    CloseHandle(info.handle);
                });
            }

            rt_moduleTlsCtor();
            scope(exit) rt_moduleTlsDtor();
            g_thisThreadId = id;
            
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

        g_threadStates.access((ref hashmap) { hashmap.put(id, ThreadStateInfo(CancelToken.init, handle)); });

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

    void joinMultipleThreads(ThreadHandle[] threads, Duration timeout)
    {
        if(timeout.isNegative)
            timeout = Duration.zero;
        WaitForMultipleObjects(cast(uint)threads.length, threads.ptr, false, cast(uint)timeout.total!"msecs");
    }
}

@("Thread - basic thread that does nothing and dies.")
unittest
{
    struct DummyContext{}
    threadRun((DummyContext _)
    {
        return SimpleResult!void.init;
    }, DummyContext.init); 
}

@("Thread - thread that returns an error")
unittest
{
    struct DummyContext{}
    threadRun((DummyContext _)
    {
        return raise("This is an error").result!void;
    }, DummyContext.init);
}

version(unittest) private int _tlsTest;
@("Thread - TLS")
unittest
{
    _tlsTest = 200;
    auto t = threadRun((int num)
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