module libd.io.filesystem;

import libd.io.stream, libd.util.errorhandling, libd.datastructures.smartptr, libd.data.conv;

@nogc nothrow:

enum FileOpenMode
{
    FAILSAFE,
    createIfNotExists,
    createAlways,
    openExisting,
    openAlways,
    truncateExisting
}

enum FileUsage
{
    FAILSAFE,
    read = 1 << 2,
    write = 1 << 1,
    readWrite = read | write
}

struct FileStream
{
    static assert(isStream!FileStream);

    @disable this(this){}

    private
    {
        FileT _file;
        FileUsage _usage;
    }

    @nogc nothrow:

    @("not for public use")
    this(FileT file, FileUsage usage)
    {
        this._file = file;
        this._usage = usage;
    }

    ~this()
    {
        if(this._file)
        {
            CloseHandle(this._file);
            this._file = null;
        }
    }

    SimpleResult!size_t write(const void[] data)
    {
        if(!this.isOpen) return typeof(return)(raise("This FileStream isn't open."));
        return fileWriteImpl(this._file, data);
    }

    SimpleResult!size_t read(scope void[] data)
    {
        if(!this.isOpen) return typeof(return)(raise("This FileStream isn't open."));
        return fileReadImpl(this._file, data);
    }
    
    bool hasData()
    {
        return false; // TODO
    }
    
    bool isOpen()
    {
        return this._file !is null;
    }

    SimpleResult!size_t getPosition()
    {
        if(!this.isOpen) return typeof(return)(raise("This FileStream isn't open."));
        return fileGetPositionImpl(this._file);
    }

    SimpleResult!void setPosition(size_t position)
    {
        if(!this.isOpen) return typeof(return)(raise("This FileStream isn't open."));
        return fileSetPositionImpl(this._file, position);
    }

    SimpleResult!size_t getSize()
    {
        if(!this.isOpen) return typeof(return)(raise("This FileStream isn't open."));
        return fileGetSizeImpl(this._file);
    }
    
    bool canPosition()
    {
        return true;
    }

    bool canWrite()
    {
        return (this._usage & FileUsage.write) > 0;
    }

    bool canRead()
    {
        return (this._usage & FileUsage.read) > 0;
    }
}

SimpleResult!(Shared!FileStream) fsOpen(const char[] file, FileOpenMode mode, FileUsage usage)
{
    auto result = fileOpenImpl(file, mode, usage);
    if(!result.isValid)
        return typeof(return)(result.error());
    return typeof(return)(makeShared(FileStream(result.value, usage)));
}

bool fsExists(const char[] path)
{
    return fsExistsImpl(path);
}

SimpleResult!void fsDelete(const char[] path)
{
    return fsDeleteImpl(path);
}

version(Windows)
{
    import runtime.system.windows;
    alias FileT = HANDLE;

    SimpleResult!FileT fileOpenImpl(const char[] file, FileOpenMode mode, FileUsage usage)
    {
        DWORD accessRights;
        if(usage & FileUsage.read)
            accessRights |= GENERIC_READ;
        if(usage & FileUsage.write)
            accessRights |= GENERIC_WRITE;

        String zeroTerm = file;
        auto handle = CreateFileA(
            zeroTerm[0..$].ptr,
            accessRights,
            0,
            null,
            cast(DWORD)mode, // values match up with win api
            FILE_ATTRIBUTE_NORMAL,
            null
        );

        if(handle == INVALID_HANDLE_VALUE)
        {
            auto error = GetLastError();
            bcstring message;

            switch(error)
            {
                case ERROR_FILE_EXISTS: message = "Could not open file: file already exists"; break;
                case ERROR_FILE_NOT_FOUND: message = "Could not open file: file does not exist"; break;
                default: message = "Could not open file: unknown"; break;
            }

            return typeof(return)(raise(
                message,
                error
            ));
        }

        return typeof(return)(handle);
    }

    SimpleResult!size_t fileWriteImpl(FileT file, const scope void[] data)
    {
        uint amountRead;
        const result = WriteFile(
            file,
            data.ptr,
            cast(uint)data.length,
            &amountRead,
            null
        );

        if(!result)
            return typeof(return)(raise("Error? TODO", GetLastError()));

        return typeof(return)(cast(size_t)amountRead);
    }

    SimpleResult!size_t fileGetSizeImpl(FileT file)
    {
        long size;
        const result = GetFileSizeEx(file, &size);

        if(!result || size < 0)
            return typeof(return)(raise("TODO", GetLastError()));

        return typeof(return)(cast(size_t)size);
    }

    SimpleResult!void fileSetPositionImpl(FileT file, size_t position)
    {
        assert(position <= long.max);
        const result = SetFilePointerEx(
            file,
            cast(long)position,
            null,
            0 // FILE_BEGIN
        );

        if(!result)
            return typeof(return)(raise("TODO", GetLastError()));

        return typeof(return)();
    }

    SimpleResult!size_t fileGetPositionImpl(FileT file)
    {
        long position;
        const result = SetFilePointerEx(
            file,
            0,
            &position,
            1 // FILE_CURRENT
        );

        if(!result || position < 0)
            return typeof(return)(raise("TODO", GetLastError()));

        return typeof(return)(cast(size_t)position);
    }

    SimpleResult!size_t fileReadImpl(FileT file, scope void[] data)
    {
        assert(data.length <= uint.max);

        uint read;
        const result = ReadFile(
            file,
            data.ptr,
            cast(uint)data.length,
            &read,
            null
        );

        if(!result)
            return typeof(return)(raise("TODO", GetLastError()));

        return typeof(return)(cast(size_t)read);
    }

    bool fsExistsImpl(const char[] path)
    {
        String zeroTerm = path;
        return cast(bool)PathFileExistsA(zeroTerm[0..$].ptr);
    }

    SimpleResult!void fsDeleteImpl(const char[] path)
    {
        String zeroTerm = path;
        const result = DeleteFileA(zeroTerm[0..$].ptr);
        
        if(!result)
            return typeof(return)(raise(GetLastErrorAsString()));

        return typeof(return)();
    }
}