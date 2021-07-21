module libd.async.coroutine;

// NOTE: This module doesn't go through the normal allocators for stack allocation, since this is bit of a special case in terms of memory allocation and management.
import libd.datastructures : LinkedList, SumType;
import libd.memory : g_alloc, PageAllocator, PageAllocation;
import libd.util.maths : alignTo;

enum DEFAULT_COROUTINE_STACK_SIZE = 0x1000*10; // For stack tracing on windows to work, we need to be a multiple of 0x1000, a.k.a the page boundary
                                               // Because after a 'fun' ASM debug session, I found out that an internal function
                                               // deep inside dbghelp.dll has a hard expectation of this alignment.
                                               // On the plus side, I learned a lot more about how to use x64dbg!

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
else static assert(false, "libd only targets x86_64");

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
    private enum REGISTERS : size_t
    {
        rsp,
        ret,
        rbx,
        rbp,
        r12,
        r13,
        r14,
        r15,

        COUNT
    }
}

package @nogc nothrow:

alias CoroutineFunc = void function() @nogc nothrow;

// TODO: Either fix TLS, or find a new mechanism to handle this.
__gshared Coroutine* g_currentThreadRoutine;
__gshared Coroutine  g_currentThreadMainRoutine;

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

extern(C) void coroutineSwap(Coroutine* from, Coroutine* to); // Implemented in NASM since D's inline ASM is a bit limited.

CoroutineStack coroutineCreateStandaloneStack(
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

void coroutineDestroyStack(ref CoroutineStack stack)
{
    releaseMemoryResources(stack);
    stack = CoroutineStack.init;
}

Coroutine* coroutineCreate(
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

void coroutineDestroy(ref Coroutine* routine)
{
    releaseMemoryResources(routine);
    g_alloc.dispose(routine);
}

void coroutineStart(Coroutine* to)
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
            to.registers[REGISTERS.rsp] = cast(ulong)standalone.context.alignedBot-8; // Need to enter a function with (RSP % 16) == 8
            version(Windows)
            version(X86_64)
            {
                to.registers[REGISTERS.gs0]  = 0;
                to.registers[REGISTERS.gs8]  = cast(ulong)standalone.context.alignedBot;
                to.registers[REGISTERS.gs16] = cast(ulong)standalone.context.alignedTop;
            }
            *(cast(void**)standalone.context.alignedBot-8) = &coroutineExit;
        }
    )(to.stack);
    g_currentThreadRoutine = to;
    coroutineSwap(from, to);
}

private void routineMain()
{
    g_currentThreadRoutine.entryPoint();
    coroutineExit();
    assert(false);
}

void coroutineReset(
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

void coroutineResume(Coroutine* routine)
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
    coroutineSwap(from, routine);
}

void* coroutineGetContext()
{
    auto routine = g_currentThreadRoutine;
    assert(routine !is null, "Cannot call this function when not inside a coroutine.");
    return routine.context;
}

void coroutineYield()
{
    yieldImpl(CoroutineState.suspended);
}

void coroutineExit()
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
    coroutineSwap(routine, next);
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
        (StandaloneStack* standalone) 
        {
            pageFree(standalone.context.pages);
            g_alloc.dispose(standalone);
        }
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
    context.alignedBot -= 56; // Win64 ABI requires a 32 byte shadow space, and we need another 8 bytes for the default return address.
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
    auto stack = coroutineCreateStandaloneStack(200, true);
    coroutineDestroyStack(stack);
}

@("coroutine - Create and Free routine")
unittest
{
    static void routine()
    {
    }

    auto stack = coroutineCreateStandaloneStack();
    auto co    = coroutineCreate(&routine, stack, null);
    coroutineDestroy(co);
    coroutineDestroyStack(stack);
}

@("coroutine - Explicit exit")
unittest
{
    static void routine()
    {
        coroutineExit();
    }

    auto stack = coroutineCreateStandaloneStack();
    auto co    = coroutineCreate(&routine, stack, null);
    coroutineStart(co);
    coroutineDestroy(co);
    coroutineDestroyStack(stack);
}

@("coroutine - Implicit exit")
unittest
{
    static void routine()
    {
    }

    auto stack = coroutineCreateStandaloneStack();
    auto co    = coroutineCreate(&routine, stack, null);
    coroutineStart(co);
    coroutineDestroy(co);
    coroutineDestroyStack(stack);  
}

@("coroutine - Suspend")
unittest
{
    __gshared static int num;

    static void routine()
    {
        num++;
        coroutineYield();
        num++;
    }

    auto stack = coroutineCreateStandaloneStack();
    auto co    = coroutineCreate(&routine, stack, null);

    coroutineStart(co);
    assert(num == 1);
    coroutineResume(co);
    assert(num == 2);

    coroutineDestroy(co);
    coroutineDestroyStack(stack);  
}

@("coroutine - Context")
unittest
{
    int num;

    static void routine()
    {
        auto ptr = cast(int*)coroutineGetContext();
        assert(ptr !is null);
        *ptr = 200;
    }

    auto stack = coroutineCreateStandaloneStack();
    auto co    = coroutineCreate(&routine, stack, &num);

    coroutineStart(co);
    assert(num == 200);

    coroutineDestroy(co);
    coroutineDestroyStack(stack);  
}

@("coroutine - Reset")
unittest
{
    int num;

    static void routine()
    {
        auto ptr = cast(int*)coroutineGetContext();
        assert(ptr !is null);
        *ptr += 1;
    }
    auto stack = coroutineCreateStandaloneStack();
    auto co    = coroutineCreate(&routine, stack, &num);

    coroutineStart(co);
    assert(num == 1);
    coroutineReset(co);
    coroutineStart(co);
    assert(num == 2);

    coroutineDestroy(co);
    coroutineDestroyStack(stack);
}