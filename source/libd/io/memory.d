module libd.io.memory;

import libd.io.stream;

struct MemoryReaderStream
{
    static assert(isStream!MemoryReaderStream);

    private const(ubyte)[] _data;
    private size_t  _cursor;

    nothrow @nogc:

    this(const ubyte[] data)
    {
        this._data = data;
    }

    SimpleResult!size_t write(const void[] data)
    {
        return typeof(return)(raise("This stream cannot read under any circumstance."));
    }

    SimpleResult!size_t read(scope void[] data)
    {
        if(!this.isOpen) return typeof(return)(raise("This MemoryReaderStream isn't open."));
        auto end = this._cursor + data.length;
        if(end > this._data.length)
            end = this._data.length;

        const amount = end - this._cursor;
        (cast(ubyte[])data)[0..amount] = this._data[this._cursor..end];
        this._cursor = end;
        return typeof(return)(cast(size_t)amount);
    }
    
    bool hasData()
    {
        return this._cursor < this._data.length;
    }
    
    bool isOpen()
    {
        return this._data !is null;
    }

    SimpleResult!size_t getPosition()
    {
        if(!this.isOpen) return typeof(return)(raise("This MemoryReaderStream isn't open."));
        return typeof(return)(this._cursor);
    }

    SimpleResult!void setPosition(size_t position)
    {
        import libd.data.format;
        if(!this.isOpen) return typeof(return)(raise("This MemoryReaderStream isn't open."));
        if(position > this._data.length) 
            return typeof(return)(raise("Cannot set position to {0} as data length is {1}".format(position, this._data.length).value));

        this._cursor = position;
        return typeof(return)();
    }

    SimpleResult!size_t getSize()
    {
        if(!this.isOpen) return typeof(return)(raise("This MemoryReaderStream isn't open."));
        return typeof(return)(this._data.length);
    }

    enum canPosition = true;
    enum canWrite = false;
    enum canRead = true;
}