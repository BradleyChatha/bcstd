/// Taken from farm_defense, which I'll eventually get back to making.
module bcstd.datastructures.mpscqueue;

import core.atomic;
import bcstd.meta : isPointer;

struct MpscBoundedQueue(T, size_t size)
{
    @disable this(this){}

    private
    {
        T[size] _buffer;
        size_t  _write;
        size_t  _write_cas;
        size_t  _read;
    }

    @nogc nothrow:

    bool enqueue(T value)
    {
        // So, the reason why we have _write_cas alongside _write is:
        //  Imagine that one thread CASes _write to its new value, but gets suspended before it writes its data into the buffer.
        //  So the _write pointer indicates to the consumer that there's data there, but there might not actually be any data there yet...
        //  So what we do is, we use _write_cas to keep producers ticking along, while only ever updating _write *after* we've 100% written data.
        while(true)
        {
            const oldWrite = this._write_cas; // This doesn't need to be an atomic load, because even if the value isn't correct, we simply end up relooping if it's not correct.
            const newWrite = (oldWrite + 1) % this._buffer.length;

            if(newWrite == this._read) // Not 100% sure if this needs to be atomically read, but I *think* we're fine here.
                return false;

            if(cas(&this._write_cas, oldWrite, newWrite))
            {
                // e.g. Our thread could be suspended here, so if we only have a single _write pointer, then we'd run into the above data race.
                this._buffer[oldWrite] = value;

                // If you think about the values of oldWrite and newWrite, you should see that this is only infinite
                // if one of the producer threads magically die here, which should only happen due to an external thing (e.g. OS closes the program), in
                // which case we don't care *anyway* since the program will stop.
                while(!cas(&this._write, oldWrite, newWrite)){}

                return true;
            }
        }
    }

    bool dequeue(ref T value)
    {
        // _read doesn't need any sort of sync, as it is only accessed by the consumer, and this queue specifically only supports 1 consumer.
        // *technically* _write should be atomically loaded I believe, but the window for error here is so small that I'd rather have the performance.
        // And it the callee is using this in a while loop, or a "try X times" loop, it's basically a non-issue anyway.
        if(this._write == this._read)
            return false;

        // This is all safe since consumers will never be able to access the data the _read pointer is at.
        value = this._buffer[this._read];
        static if(is(T == class) || is(T == interface) || isPointer!T)
            this._buffer[this._read] = T.init;

        // However, *now* they can.
        this._read = (this._read + 1) % this._buffer.length;
        return true;
    }

    bool peek(ref T value)
    {
        // Again, _read is only used by the consumer, and producers can't access the data at the _read pointer, so no sync is needed.
        if(this._write == this._read)
            return false;

        value = this._buffer[this._read];
        return true;
    }
}
///
@("MspcBoundedQueue")
version(none) // Bit of a manual test this one.
unittest
{
    import bcstd.threading, bcstd.util.errorhandling;
    MpscBoundedQueue!(int, 10*100) queue;

    foreach(i; 0..10)
    {
        runThread((typeof(queue)* ptr)
        {
            foreach(i; 0..1000)
            {
                import std;
                ptr.enqueue(i);
                sleep(uniform(0, 50).msecs);
            }
            return SimpleResult!void.init;
        }, &queue);
    }

    int sum;
    int num;
    while(queue.dequeue(num))
    {
        import std;
        writeln(num, " ", sum);
        sum += num;
        sleep(100.msecs);
    }
}