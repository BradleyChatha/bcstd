module bcstd.async.coroutine;

// NOTE: This module doesn't go through the normal allocators for stack allocation, since this is bit of a special case in terms of memory allocation and management.
import core.exception : onOutOfMemoryError;
import bcstd.datastructures : LinkedList, SumType;
import bcstd.memory : g_alloc, PageAllocator, PageAllocation;
import bcstd.util.maths : alignTo;

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
    stack = CoroutineStack.init;
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
        (StandaloneStack* standalone) => pageFree(standalone.context.pages)
    )(stack);
}

private @nogc nothrow:

struct StackContext
{
    ubyte* base;
    ubyte* alignedTop;
    ubyte* alignedBot;
    PageAllocation pages;
}

StackContext pageAlloc(size_t minSize, bool useGuardPage)
{
    StackContext context;

    auto alloc = PageAllocator.allocInBytesToPages(minSize, useGuardPage);
    
    context.base       = alloc.memory.ptr;
    context.alignedBot = (alloc.memory.ptr + alloc.memory.length);
    context.alignedTop = alloc.memory.ptr;
    context.alignedBot -= 40; // Win64 ABI requires a 32 byte shadow space, and we need another 8 bytes for the default return address.
    context.alignedBot = cast(ubyte*)((cast(ulong)context.alignedBot).alignTo!16);
    context.alignedTop = cast(ubyte*)((cast(ulong)context.alignedTop).alignTo!16);
    context.pages      = alloc;

    return context;
}

void pageFree(PageAllocation pages)
{
    PageAllocator.free(pages);
}

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