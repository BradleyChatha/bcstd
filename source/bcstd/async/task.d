module bcstd.async.task;

import bcstd.async.coroutine;

enum TaskState
{
    uninit,
    running,
    yielded,
    done
}

struct Task
{
    private Coroutine*  _coroutine;
    private TaskState   _state;

    @nogc nothrow:

    void resume()
    {
        assert(this.isValid, "This task is in an invalid state.");
        final switch(this._coroutine.state) with(CoroutineState)
        {
            case start: bcstdStartCoroutine(this._coroutine); break;
            case running: assert(false, "This task is already running.");
            case suspended: bcstdResumeCoroutine(this._coroutine); break;
            case end: assert(false, "This task has finished.");
        }
    }

    TaskState state() const
    {
        return this._state;
    }

    bool isValid() const pure
    {
        return this._coroutine !is null;
    }
}