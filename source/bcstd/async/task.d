module bcstd.async.task;

import bcstd.async.coroutine;
import bcstd.datastructures : TypedPtr;
import bcstd.memory : OnMove;
import bcstd.util : BcError;

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
    TypedPtr userContext;
    BcError  error;
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

        // TODO: Stack customisation, and better stack management.
        //       This is intentionally not freed to encourage me to get to it.
        auto stack = bcstdCreateStandaloneCoroutineStack();
        this._coroutine = bcstdCreateCoroutine(func, stack, &this._context);
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
        assert(!this.hasErrored, "This task has errored. Used `.error` to see what went wrong.");
        this._state = TaskState.running;
        final switch(this._coroutine.state) with(CoroutineState)
        {
            case start: bcstdStartCoroutine(this._coroutine); break;
            case running: assert(false, "This task is already running.");
            case suspended: bcstdResumeCoroutine(this._coroutine); break;
            case end: assert(false, "This task has finished.");
        }

        if(this._context.error != BcError.init)
            this._state = TaskState.errored;
    }

    void dispose()
    {
        assert(this.isValid, "This task is in an invalid state.");
        this._state = TaskState.uninit;
        bcstdDestroyCoroutine(this._coroutine);
        this._coroutine = null;
    }

    @property
    TaskState state() const
    {
        return this._state;
    }

    @property
    bool isValid() const pure
    {
        return this._coroutine !is null;
    }

    @property
    BcError error()
    {
        assert(this.hasErrored, "This task hasn't errored, there's no reason for this to be called.");
        return this._context.error;
    }

    @property @safe
    bool hasErrored() const pure
    {
        return this._state == TaskState.errored;
    }
}