module libd.util.errorhandling;

import libd.datastructures.sumtype;
import  libd.datastructures.string, libd.data.conv, libd.memory, libd.meta;

@nogc nothrow:

struct BcError
{
    String file;
    String function_;
    String module_;
    size_t line;
    int errorCode; // Function/Library specific.
    String message;
}

struct SimpleResult(T)
{
    static if(is(T == void))
        private bool _isValid = true;
    else
        private bool _isValid = false;
    private BcError _error;

    static if(!is(T == void))
    private T       _value;

    static if(__traits(hasCopyConstructor, T))
    {
        @disable
        this(this){}
    }

    @nogc nothrow:

    static if(!is(T == void))
    this()(auto ref T value)
    {
        static if(isCopyable!T)
            this._value = value;
        else
            move(value, this._value);
        this._isValid = true;
    }

    this(BcError error)
    {
        this._error = error;
        this._isValid = false;
    }

    @property @safe @nogc
    bool isValid() nothrow pure const
    {
        return this._isValid;
    }

    static if(!is(T == void))
    @property
    ref inout(T) value()() inout
    {
        assert(this._isValid, "Attempted to get value of invalid result.");
        return this._value;
    }

    @property
    BcError error()
    {
        assert(!this._isValid, "Attempted to get value of not-invalid result.");
        return this._error;
    }
}

SimpleResult!ValueT result(ValueT)(auto ref BcError error)
{
    return typeof(return)(error);
}

SimpleResult!ValueT result(ValueT)(auto ref ValueT value)
{
    return typeof(return)(value);
}

BcError raise(string File = __FILE_FULL_PATH__, string Function = __PRETTY_FUNCTION__, string Module = __MODULE__, size_t Line = __LINE__)(
    bcstring message,
    int errorCode = 0
)
{
    return raise!(File, Function, Module, Line)(String(message), errorCode);
}

BcError raise(string File = __FILE_FULL_PATH__, string Function = __PRETTY_FUNCTION__, string Module = __MODULE__, size_t Line = __LINE__)(
    String message,
    int errorCode = 0
)
{
    auto error = BcError(
        String(File),
        String(Function),
        String(Module),
        Line,
        errorCode
    );
    error.message = message;

    return error;
}

auto assumeValid(ResultT)(auto ref ResultT result)
{
    if(!result.isValid)
        throwError(result.error);

    static if(__traits(hasMember, ResultT, "value"))
        return result.value;
}
///
@("assumeValid")
unittest
{
    SimpleResult!int a = 69.result;
    SimpleResult!int b = raise("yolo swag").result!int;

    assert(a.assumeValid == 69);

    // bool threw;
    // try b.assumeValid();
    // catch(Error e) threw = true;
    // assert(threw);
}

void throwError(BcError error)
{
    displayError(error);
    assert(false);
}

void formatError(OutputRange)(ref OutputRange output, BcError error)
{
    const part1    = "Unexpected error:\n";
    const part2    = "    File:     ";
    const part3    = "    Module:   ";
    const part4    = "    Function: ";
    const part5    = "    Line:     ";
    const part6    = "    Code:     ";
    const part7    = "    Message:  ";
    const maxSizeT = "18446744073709551615";
    
    static if(__traits(hasMember, output, "reserve"))
    output.reserve(
          part1.length
        + part2.length
        + part3.length
        + part4.length
        + part5.length           + maxSizeT.length
        + part6.length           + maxSizeT.length
        + part7.length           + error.message.length
        + error.file.length      + 2 // + 2 to include padding
        + error.function_.length + 2
        + error.module_.length   + 2
    );

    output.put(part1);
    output.put(part2); output.put(error.file.range);                output.put('\n');
    output.put(part3); output.put(error.module_.range);             output.put('\n');
    output.put(part4); output.put(error.function_.range);           output.put('\n');
    output.put(part5); output.put(error.line.to!String.range);      output.put('\n');
    output.put(part6); output.put(error.errorCode.to!String.range); output.put('\n');
    output.put(part7); output.put(error.message.sliceUnsafe);

    output.put('\0');
}

void displayError(BcError error)
{
    import libd.datastructures : Array;
    import libd.console.io;

    Array!char output;
    formatError(output, error);
    consoleWriteln(output[0..$]);
}

void bcAssert(string File = __FILE_FULL_PATH__, string Function = __PRETTY_FUNCTION__, string Module = __MODULE__, size_t Line = __LINE__)(
    bool condition,
    bcstring message = null
)
{
    if(!condition)
        throwError(raise!(File, Function, Module, Line)(message));
}

void onOutOfMemoryError(void* pretend_sideeffect)
{
    assert(false);
}