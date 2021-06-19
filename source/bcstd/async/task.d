module bcstd.async.task;

import bcstd.object;
import bcstd.async.coroutine;
import bcstd.datastructures : TypedPtr, makeTyped;
import bcstd.memory : OnMove;
import bcstd.util : BcError, raise, displayError;

enum TaskState
{
    uninit,
    running,
    yielded,
    errored,
    done
}

private struct TaskContext
{
    TypedPtr      userContext;
    TypedPtr      yieldValue;
    CoroutineFunc entryPoint;
    BcError       error;
    bool          yieldedWithValue;
}

@(OnMove.callUpdateInternalPointers)
struct Task
{
    private Coroutine*  _coroutine;
    private TaskState   _state;
    private TaskContext _context;

    @disable this(this){}

    @nogc nothrow:

    this(CoroutineFunc func)
    {
        this(func, null);
    }

    this(T)(CoroutineFunc func, auto ref T context)
    {
        static if(!is(T == typeof(null)))
            this._context.userContext = context.makeTyped;

        // TODO: Stack customisation. New PageAllocator means memory is managed a lot better now.
        auto stack = bcstdCreateStandaloneCoroutineStack();
        this._context.entryPoint = func;
        this._coroutine = bcstdCreateCoroutine(&coroutine, stack, &this._context);
    }

    private static void coroutine()
    {
        auto ctx = cast(TaskContext*)bcstdGetCoroutineContext();
        assert(ctx !is null, "This was not called during a task. Tasks are a more focused layer placed on top of coroutines.");
        assert(ctx.entryPoint !is null, "No/null entrypoint was given.");
        version(D_BetterC)
            ctx.entryPoint();
        else // So unittests don't completely crash on failure (most of the time).
        {
            try ctx.entryPoint();
            catch(Error e)
            {
                yieldRaise(e.msg);
            }
        }
        bcstdExitCoroutine();
    }

    ~this()
    {
        if(this.isValid)
            this.dispose();
    }

    void updateInternalPointers()
    {
        if(this._coroutine !is null)
            this._coroutine.context = &this._context;
    }

    void resume()
    {
        assert(this.isValid, "This task is in an invalid state.");
        assert(!this.hasError, "This task has errored. Used `.error` to see what went wrong.");
        this._state = TaskState.running;
        this._context.yieldedWithValue = false;
        final switch(this._coroutine.state) with(CoroutineState)
        {
            case start: bcstdStartCoroutine(this._coroutine); break;
            case running: assert(false, "This task is already running.");
            case suspended: bcstdResumeCoroutine(this._coroutine); break;
            case end: assert(false, "This task has finished.");
        }

        if(this._context.error != BcError.init)
        {
            displayError(this._context.error); // Not ideal, but it's fine until there's a logging system up
            this._state = TaskState.errored;
        }
        else if(this._coroutine.state == CoroutineState.suspended)
            this._state = TaskState.yielded;
        else if(this._coroutine.state == CoroutineState.end)
            this._state = TaskState.done;
    }

    void dispose()
    {
        assert(this.isValid, "This task is in an invalid state.");
        this._state = TaskState.uninit;
        bcstdDestroyCoroutine(this._coroutine);
        this._coroutine = null;
    }

    ref T valueAs(alias T)()
    {
        assert(this.hasValue);
        return *this._context.yieldValue.ptrUnsafeAs!T;
    }

    @property @safe
    TaskState state() const
    {
        return this._state;
    }

    @property @safe
    bool isValid() const pure
    {
        return this._coroutine !is null;
    }

    @property
    BcError error()
    {
        assert(this.hasError, "This task hasn't errored, there's no reason for this to be called.");
        return this._context.error;
    }

    @property @safe
    bool hasError() const pure
    {
        assert(this.isValid);
        return this._state == TaskState.errored;
    }

    @property @safe
    bool hasYielded() const pure
    {
        assert(this.isValid);
        return this._state == TaskState.yielded;
    }

    @property @safe
    bool hasEnded() const pure
    {
        assert(this.isValid);
        return this._state == TaskState.done || this.hasError;
    }

    @property @safe
    bool hasValue() const pure
    {
        assert(this.isValid);
        return this._state == TaskState.yielded && this._context.yieldedWithValue;
    }
}

void runTask(T)(ref return Task task, CoroutineFunc func, auto ref T context = null)
{
    import bcstd.memory : emplaceCtor;
    emplaceCtor(task, func, context);
    task.resume();
}

@nogc nothrow
void yield()
{
    bcstdYieldCoroutine();
}

@nogc nothrow
void yieldRaise(BcError error)
{
    auto ctx = cast(TaskContext*)bcstdGetCoroutineContext();
    assert(ctx !is null, "This was not called during a task. Tasks are a more focused layer placed on top of coroutines.");
    ctx.error = error;
    yield();
}

void yieldRaise(string File = __FILE_FULL_PATH__, string Function = __PRETTY_FUNCTION__, string Module = __MODULE__, size_t Line = __LINE__)(
    bcstring message,
    int errorCode = 0
)
{
    yieldRaise(raise!(File, Function, Module, Line)(message, errorCode));
}

void yieldValue(T)(auto ref T value)
{
    auto ctx = cast(TaskContext*)bcstdGetCoroutineContext();
    assert(ctx !is null, "This was not called during a task. Tasks are a more focused layer placed on top of coroutines.");
    ctx.yieldValue.setByForce(value);
    ctx.yieldedWithValue = true;
    yield();
}

void accessTaskContext(alias T, alias Func)()
{
    auto ctx = cast(TaskContext*)bcstdGetCoroutineContext();
    assert(ctx !is null, "This was not called during a task. Tasks are a more focused layer placed on top of coroutines.");
    ctx.userContext.access!T((scope ref T value) { Func(value); });
}

@("task - basic")
unittest
{
    Task task;
    runTask(task, (){
        yield();
    });

    assert(task.isValid);
    assert(task.hasYielded);
    task.resume();
    assert(task.hasEnded);
}

@("task - context")
unittest
{
    Task task;
    int num;
    runTask(task, (){
        accessTaskContext!(int*, (scope ref ptr){
            (*ptr)++;
        });
        yield();
        accessTaskContext!(int*, (scope ref ptr){
            (*ptr)++;
        });
    }, &num);

    assert(num == 1);
    task.resume();
    assert(num == 2);
}

@("task - error")
unittest
{
    Task task;
    runTask(task, (){ yieldRaise("error"); });
    assert(task.hasEnded && task.hasError);
    assert(task.error.message == "error");
}

@("task - value")
unittest
{
    Task task;
    runTask(task, (){
        yieldValue(1);
        yieldValue("string");
    });
    assert(task.hasYielded && task.hasValue);
    assert(task.valueAs!int == 1);
    task.resume();
    assert(task.hasYielded && task.hasValue);
    assert(task.valueAs!string == "string");
    task.resume();
    assert(task.hasEnded);
}

@("task - move support")
unittest
{
    import bcstd.memory : move;

    Task task;
    Task moved;
    int num = 200;
    runTask(task, (){
        yield();
        accessTaskContext!(int*, (scope ref ptr){
            assert(*ptr == 200);
            *ptr *= 2;
        });
    }, &num);

    move(task, moved);
    moved.resume();
    assert(moved.hasEnded);
    assert(num == 400);
}