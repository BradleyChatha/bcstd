module bcstd.async.coroutine;

// NOTE: This module doesn't go through the normal allocators for stack allocation, since this is bit of a special case in terms of memory allocation and management.
import bcstd.datastructures : LinkedList, SumType;
import bcstd.memory : g_alloc;

enum DEFAULT_COROUTINE_STACK_SIZE = 1024 * 10;

version(X86_64)
{
    version(Windows)
    {
        private enum Win64 = true;
        private enum SysV  = false;
    }
    else version(linux)
    {
        private enum Win64 = false;
        private enum SysV  = true;
    }
    else static assert(false, "Unsupported platform.");
}
else static assert(false, "bcstd only targets x86_64");

// CONSTANTS
static if(Win64)
{
    private enum REGISTERS : size_t
    {
        rsp,
        ret,
        r12,
        r13,
        r14,
        r15,
        rdi,
        rsi,
        rbx,
        rbp,
        gs0,
        gs8,
        gs16,

        COUNT
    }
}
else static if(SysV)
{
}

package @nogc nothrow:

alias CoroutineFunc = void function() @nogc nothrow;

Coroutine* g_currentThreadRoutine;
Coroutine  g_currentThreadMainRoutine;

enum CoroutineState : ubyte
{
    start,
    running,
    suspended,
    end
}

struct Coroutine
{
    ulong[REGISTERS.COUNT] registers;
    CoroutineState state;
    CoroutineFunc entryPoint;
    void* context;
    LinkedList!(Coroutine*) callStack;
    CoroutineStack stack;
    CoroutineSuspendedStack suspendedStack;

    @safe @nogc nothrow pure const
    bool isMain()
    {
        return this.callStack.length == 0;
    }
}

union CoroutineStackUnion
{
    StandaloneStack* standalone;
}

struct StandaloneStack
{
    StackContext context;
    Coroutine* owner;
}

alias CoroutineStack = SumType!CoroutineStackUnion;

struct CoroutineSuspendedStack
{
    ubyte[] memory;
}

extern(C) void bcstdCoroutineSwap(Coroutine* from, Coroutine* to); // Implemented in NASM since D's inline ASM is a bit limited.

CoroutineStack bcstdCreateStandaloneCoroutineStack(
    size_t minMemory = DEFAULT_COROUTINE_STACK_SIZE,
    bool useGuardPage = true
)
{
    auto alloc = pageAlloc(minMemory, useGuardPage);
    auto stack = g_alloc.make!StandaloneStack(alloc);
    if(stack is null)
        onOutOfMemoryError(null);
    return CoroutineStack(stack.ptr);
}

void bcstdDestroyCoroutineStack(ref CoroutineStack stack)
{
    releaseMemoryResources(stack);
    //stack = CoroutineStack.init;
}

Coroutine* bcstdCreateMainCoroutine()
{
    return &g_currentThreadMainRoutine;
}

Coroutine* bcstdCreateCoroutine(
    CoroutineFunc func,
    CoroutineStack stack,
    void* context,
)
{
    auto ptr = g_alloc.make!Coroutine();
    assert(ptr !is null);

    ptr.entryPoint = func;
    ptr.context = context;
    ptr.stack = stack;
    return ptr;
}

void bcstdDestroyCoroutine(ref Coroutine* routine)
{
    releaseMemoryResources(routine);
    g_alloc.dispose(routine);
}

void bcstdStartCoroutine(Coroutine* to)
{
    auto from = g_currentThreadRoutine;
    if(from is null)
        from = &g_currentThreadMainRoutine;
    assert(to !is null, "To is null");
    assert(to.state == CoroutineState.start, "Child is not in the `start` state.");
    assert(to.entryPoint !is null, "Child has no entry point.");
    
    to.callStack.put(from);
    from.state = CoroutineState.suspended;
    to.state = CoroutineState.running;

    to.registers[REGISTERS.ret] = cast(ulong)&routineMain;

    to.stack.visit!(
        (StandaloneStack* standalone)
        {
            assert(standalone.owner is null, "There is currently another coroutine making use of this standalone stack.");
            standalone.owner = to;
            to.registers[REGISTERS.rsp] = cast(ulong)standalone.context.alignedBot;
            version(Windows)
            version(X86_64)
            {
                to.registers[REGISTERS.gs0]  = 0;
                to.registers[REGISTERS.gs8]  = cast(ulong)standalone.context.alignedBot;
                to.registers[REGISTERS.gs16] = cast(ulong)standalone.context.alignedTop;
            }
            *(cast(void**)standalone.context.alignedBot) = &bcstdExitCoroutine;
        }
    )(to.stack);
    g_currentThreadRoutine = to;
    bcstdCoroutineSwap(from, to);
}

private void routineMain()
{
    g_currentThreadRoutine.entryPoint();
    bcstdExitCoroutine();
    assert(false);
}

void bcstdResetCoroutine(
    Coroutine* routine,
    void* newContext = null,
    CoroutineFunc newEntryPoint = null,
)
{
    assert(routine.state == CoroutineState.end, "Routine is not in the `end` state.");
    assert(routine.callStack.length == 0, "Routine still has values on the call stack?");
    routine.registers[] = 0;
    if(newContext)
        routine.context = newContext;
    if(newEntryPoint)
        routine.entryPoint = newEntryPoint;
    releaseMemoryResources(routine, true);
    routine.state = CoroutineState.start;
}

void bcstdResumeCoroutine(Coroutine* routine)
{
    auto from = g_currentThreadRoutine;
    if(from is null)
        from = &g_currentThreadMainRoutine;
    assert(routine !is null, "Routine is null.");
    assert(routine.state == CoroutineState.suspended, "Routine is not in the `suspended` state.");

    routine.callStack.put(from);
    from.state = CoroutineState.suspended;
    routine.state = CoroutineState.running;
    g_currentThreadRoutine = routine;
    bcstdCoroutineSwap(from, routine);
}

void* bcstdGetCoroutineContext()
{
    auto routine = g_currentThreadRoutine;
    assert(routine !is null, "Cannot call this function when not inside a coroutine.");
    return routine.context;
}

void bcstdYieldCoroutine()
{
    yieldImpl(CoroutineState.suspended);
}

void bcstdExitCoroutine()
{
    yieldImpl(CoroutineState.end);
    assert(false);
}

private void yieldImpl(CoroutineState endState)
{
    auto routine = g_currentThreadRoutine;
    assert(routine !is null, "Cannot call this function when not inside a coroutine.");
    assert(routine.callStack.length > 0, "Coroutine has no call stack?");

    routine.state = endState;
    auto next = routine.callStack.removeAtTail(routine.callStack.length - 1);
    assert(next.state == CoroutineState.suspended, "Call stack routine is not in suspended state?");
    g_currentThreadRoutine = next;
    next.state = CoroutineState.running;
    bcstdCoroutineSwap(routine, next);
}

private void releaseMemoryResources(Coroutine* routine, bool isForReset = false)
{
    routine.stack.visit!(
        (StandaloneStack* standalone)
        {
            if(routine.state == CoroutineState.running || routine.state == CoroutineState.suspended)
                assert(standalone.owner is routine, "??");
            standalone.owner = null;
        }
    )(routine.stack);
}

private void releaseMemoryResources(CoroutineStack stack)
{
    stack.visit!(
        (StandaloneStack* standalone) => pageFree(standalone.context.base)
    )(stack);
}

private @nogc nothrow:

struct StackContext
{
    ubyte* base;
    ubyte* alignedTop;
    ubyte* alignedBot;
}

pragma(inline, true)
size_t align16(size_t value) pure
{
    return value & ~16;
}

version(Windows)
{
    import core.exception : onOutOfMemoryError;
    import core.sys.windows.windows : SYSTEM_INFO, GetSystemInfo, VirtualAlloc, VirtualFree, VirtualProtect, MEM_COMMIT, MEM_RESERVE,
                                      PAGE_GUARD, PAGE_READONLY, PAGE_READWRITE, DWORD, MEM_RELEASE;

    StackContext pageAlloc(size_t minSize, bool useGuardPage)
    {
        StackContext context;
        
        SYSTEM_INFO info;
        GetSystemInfo(&info);

        auto totalSize = minSize;
        if(totalSize < info.dwPageSize)
            totalSize = info.dwPageSize;
            
        if(useGuardPage)
            totalSize += info.dwPageSize;

        auto ptr = VirtualAlloc(null, totalSize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if(ptr is null)
            onOutOfMemoryError(null);
        context.base       = cast(ubyte*)ptr;
        context.alignedBot = cast(ubyte*)(ptr + totalSize);
        context.alignedTop = cast(ubyte*)(cast(ulong)ptr);

        if(useGuardPage)
        {
            DWORD _;
            const result = VirtualProtect(ptr, info.dwPageSize, PAGE_READONLY | PAGE_GUARD, &_);
            if(!result)
                assert(false, "VirtualProtect failed");
            context.alignedTop += info.dwPageSize;
        }

        context.alignedBot -= 40; // Win64 ABI requires a 32 byte shadow space, and we need another 8 bytes for the default return address.
        context.alignedBot = cast(ubyte*)((cast(ulong)context.alignedBot).align16);
        context.alignedTop = cast(ubyte*)((cast(ulong)context.alignedTop).align16);

        return context;
    }

    void pageFree(void* baseAddress)
    {
        const result = VirtualFree(baseAddress, 0, MEM_RELEASE);
        if(!result)
            assert(false, "VirtualFree failed.");
    }
}
else static assert(false, "TODO for Linux");

@("coroutine - Create and Free stack")
unittest
{
    auto stack = bcstdCreateStandaloneCoroutineStack(200, true);
    bcstdDestroyCoroutineStack(stack);
}

@("coroutine - Create and Free routine")
unittest
{
    static void routine()
    {
    }

    auto main  = bcstdCreateMainCoroutine();
    auto stack = bcstdCreateStandaloneCoroutineStack();
    auto co    = bcstdCreateCoroutine(&routine, stack, null);
    bcstdDestroyCoroutine(co);
    bcstdDestroyCoroutineStack(stack);
}

@("coroutine - Explicit exit")
unittest
{
    static void routine()
    {
        bcstdExitCoroutine();
    }

    auto main  = bcstdCreateMainCoroutine();
    auto stack = bcstdCreateStandaloneCoroutineStack();
    auto co    = bcstdCreateCoroutine(&routine, stack, null);
    bcstdStartCoroutine(co);
    bcstdDestroyCoroutine(co);
    bcstdDestroyCoroutineStack(stack);
}

@("coroutine - Implicit exit")
unittest
{
    static void routine()
    {
    }

    auto main  = bcstdCreateMainCoroutine();
    auto stack = bcstdCreateStandaloneCoroutineStack();
    auto co    = bcstdCreateCoroutine(&routine, stack, null);
    bcstdStartCoroutine(co);
    bcstdDestroyCoroutine(co);
    bcstdDestroyCoroutineStack(stack);  
}

@("coroutine - Suspend")
unittest
{
    static int num;

    static void routine()
    {
        num++;
        bcstdYieldCoroutine();
        num++;
    }

    auto main  = bcstdCreateMainCoroutine();
    auto stack = bcstdCreateStandaloneCoroutineStack();
    auto co    = bcstdCreateCoroutine(&routine, stack, null);

    bcstdStartCoroutine(co);
    assert(num == 1);
    bcstdResumeCoroutine(co);
    assert(num == 2);

    bcstdDestroyCoroutine(co);
    bcstdDestroyCoroutineStack(stack);  
}

@("coroutine - Context")
unittest
{
    int num;

    static void routine()
    {
        auto ptr = cast(int*)bcstdGetCoroutineContext();
        assert(ptr !is null);
        *ptr = 200;
    }

    auto main  = bcstdCreateMainCoroutine();
    auto stack = bcstdCreateStandaloneCoroutineStack();
    auto co    = bcstdCreateCoroutine(&routine, stack, &num);

    bcstdStartCoroutine(co);
    assert(num == 200);

    bcstdDestroyCoroutine(co);
    bcstdDestroyCoroutineStack(stack);  
}

@("coroutine - Reset")
unittest
{
    int num;

    static void routine()
    {
        auto ptr = cast(int*)bcstdGetCoroutineContext();
        assert(ptr !is null);
        *ptr += 1;
    }
    auto main  = bcstdCreateMainCoroutine();
    auto stack = bcstdCreateStandaloneCoroutineStack();
    auto co    = bcstdCreateCoroutine(&routine, stack, &num);

    bcstdStartCoroutine(co);
    assert(num == 1);
    bcstdResetCoroutine(co);
    bcstdStartCoroutine(co);
    assert(num == 2);

    bcstdDestroyCoroutine(co);
    bcstdDestroyCoroutineStack(stack);
}