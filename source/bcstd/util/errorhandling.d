module bcstd.util.errorhandling;

import bcstd.datastructures : SumType;
import bcstd.object, bcstd.datastructures.string, bcstd.util.conv;

enum BC_ERROR_MAX_MESSAGE_SIZE = 512;

@nogc nothrow:

struct BcError
{
    string file;
    string function_;
    string module_;
    size_t line;
    int errorCode; // Function/Library specific.
    String message;
}

template ValueOrError(alias ValueT)
{
    union U
    {
        ValueT value;
        BcError error;
    }

    alias ValueOrError = SumType!U;
}
private struct MaybeErrorV{}
alias MaybeError = ValueOrError!MaybeErrorV;

BcError raise(string File = __FILE_FULL_PATH__, string Function = __PRETTY_FUNCTION__, string Module = __MODULE__, size_t Line = __LINE__)(
    bcstring message,
    int errorCode = 0
)
{
    if(message.length > BC_ERROR_MAX_MESSAGE_SIZE)
        message = message[0..BC_ERROR_MAX_MESSAGE_SIZE];

    auto error = BcError(
        File,
        Function,
        Module,
        Line,
        errorCode
    );
    error.message = message[0..$];

    return error;
}

auto assertNotError(ValueOrErrorT)(auto ref ValueOrErrorT valueOrError)
{
    static if(is(ValueOrErrorT == MaybeError))
    {
        if(valueOrError == MaybeError.init && valueOrError.contains!(BcError))
            throwError(valueOrError.get!BcError);
    }
    else
    {
        if(valueOrError.contains!BcError)
            throwError(valueOrError.get!BcError);

        return valueOrError.get!(typeof(ValueOrErrorT.Union.tupleof[0]));
    }
}
///
@("assertNotError")
unittest
{
    ValueOrError!int a = 69;
    ValueOrError!int b = raise("yolo swag");

    assert(a.assertNotError == 69);

    bool threw;
    try b.assertNotError();
    catch(Error e) threw = true;
    assert(threw);
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
    output.put(part2); output.put(error.file);                      output.put('\n');
    output.put(part3); output.put(error.module_);                   output.put('\n');
    output.put(part4); output.put(error.function_);                 output.put('\n');
    output.put(part5); output.put(error.line.to!String.range);      output.put('\n'); // TODO: Put in the line number once bcstd can format things into text
    output.put(part6); output.put(error.errorCode.to!String.range); output.put('\n');
    output.put(part7); output.put(error.message.sliceUnsafe);

    output.put('\0');
}

void displayError(BcError error)
{
    import core.stdc.stdio : printf; // TODO Replace this once bcstd has it's own ability to print.
    import bcstd.datastructures : Array;

    Array!char output;
    formatError(output, error);
    printf("%s\n", output[].ptr);
}

void bcAssert(string File = __FILE_FULL_PATH__, string Function = __PRETTY_FUNCTION__, string Module = __MODULE__, size_t Line = __LINE__)(
    bool condition,
    bcstring message = null
)
{
    if(!condition)
        throwError(raise!(File, Function, Module, Line)(message));
}