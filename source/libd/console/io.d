module libd.console.io;

import libd.io.filesystem;

__gshared FileStream g_stdout;
__gshared FileStream g_stderr;
__gshared FileStream g_stdin;

void consoleWrite(Params...)(scope Params params) { consoleWriteImpl!g_stdout(params); }
void consoleWriteln(Params...)(scope Params params) { consoleWritelnImpl!g_stdout(params); }
bool consoleWritef(Params...)(scope bcstring spec, scope Params params) { return consoleWritefImpl!g_stdout(spec, params); }
bool consoleWritefln(Params...)(scope bcstring spec, scope Params params) { return consoleWriteflnImpl!g_stdout(spec, params); }

bcstring consoleRead(scope char[] buffer)
{
    if(!g_stdin.isOpen)
        return null;

    const result = g_stdin.read(buffer);
    if(!result.isValid)
        return null;

    return buffer[0..result.value];
}

String consoleRead(size_t maxInput = 512)()
{
    char[maxInput] buffer;

    auto result = String(consoleRead(buffer[0..$]));
    if(result.length && result[$-1] == '\n') // Remove the \n that usually comes through when the user presses ENTER
        result.length = result.length - 1;

    return result;
}

private void consoleWriteImpl(alias Stream, Params...)(scope Params params)
{
    import libd.data.conv;
    if(Stream.isOpen)
    {
        static foreach(i, param; params)
        {{
            alias ParamT = typeof(param);
            static if(is(ParamT : bcstring))
                Stream.write(param);
            else static if(is(ParamT : const String))
                Stream.write(params[i][0..$]);
            else static if(is(ParamT == bool))
                Stream.write(param ? "true" : "false");
            else static if(is(ParamT : const char))
                Stream.write((&params[i])[0..1]);
            else
                Stream.write(params[i].to!String[0..$]);
        }}
    }
}

private void consoleWritelnImpl(alias Stream, Params...)(scope Params params)
{
    consoleWriteImpl!Stream(params);
    Stream.write("\n");
}

private bool consoleWritefImpl(alias Stream, Params...)(scope bcstring spec, scope Params params)
{
    import libd.data.format;

    auto result = format(spec, params);
    if(!result.isValid)
    {
        consoleWritelnImpl!Stream("Failed to format string.");
        displayError(result.error);
        return false;
    }

    consoleWriteImpl!Stream(result.value[0..$]);
    return true;
}

private bool consoleWriteflnImpl(alias Stream, Params...)(scope bcstring spec, scope Params params)
{
    const result = consoleWritefImpl!Stream(spec, params);
    if(!result)
        return false;

    Stream.write("\n");
    return true;
}

@("not for public use")
void _d_console_io_init()
{
    version(Windows)
    {
        import runtime.system.windows;
        void createStream(ref FileStream file, DWORD stdType, FileUsage usage)
        {
            const result = GetStdHandle(stdType);
            if(result == INVALID_HANDLE_VALUE || !result)
                return;
            file = FileStream(cast(HANDLE)result, usage);
        }

        createStream(g_stdout, STD_OUTPUT_HANDLE, FileUsage.write);
        createStream(g_stderr, STD_ERROR_HANDLE, FileUsage.write);
        createStream(g_stdin, STD_INPUT_HANDLE, FileUsage.read);

        HANDLE stdOut = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD mode = 0;
        GetConsoleMode(stdOut, &mode);
        mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        SetConsoleMode(stdOut, mode);
    }
}