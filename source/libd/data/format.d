module libd.data.format;

import libd.datastructures.string,  libd.datastructures.sumtype, libd.datastructures.array,
       libd.algorithm.search, libd.util.errorhandling, libd.data.conv;

private enum MAX_FORMAT_PARAMS = 5;

struct FormatSegment
{
    bcstring formatter; // Can be null
    bcstring[MAX_FORMAT_PARAMS] params;
    ubyte paramCount;
    ubyte formatItemIndex;
}

union FormatStringInfoValues
{
    FormatSegment formatted;
    bcstring unformatted;
}

alias FormatStringInfo = SumType!FormatStringInfoValues;

SimpleResult!String format(Params...)(scope bcstring spec, scope Params params)
{
    String result;
    BcError error;
    bool throwError = false;

    defaultFormatter(spec, result, error, throwError, params);

    if(throwError)
        return error.result!String;

    return result.result;
}
///
@("format (formatInfoPusher & defaultFormatter by proxy)")
unittest
{
    struct DoeRayMe
    {
        string easyAs;
        int oneTwoThree;
    }

    assert(format("abc").assumeValid == "abc");
    assert(format("abc {1:} {0}", 123, "easy as").assumeValid == "abc easy as 123");
    assert(format("abc {0}", DoeRayMe("hard as", 321)).assumeValid == `abc DoeRayMe("hard as", 321)`);
}

@nogc
void defaultFormatter(ResultT, Params...)(scope bcstring spec, scope ref ResultT result, scope ref BcError error, scope ref bool throwError, scope Params params) nothrow
{
    formatInfoPusher(spec, (info)
    {
        if(throwError)
            return;
        if(!info.isValid)
        {
            throwError = true;
            error = info.error;
            return;
        }

        auto value = info.value;
        value.visit!(
            (bcstring raw) { result.put(raw); },
            (FormatSegment segment) 
            {
                Switch: switch(segment.formatItemIndex)
                {
                    static foreach(i; 0..Params.length)
                    {
                        case i:
                            defaultFormatterSegmentHandler(result, segment, params[i]);
                            break Switch;
                    }

                    default:
                        throwError = true;
                        error = raise("Parameter index out of bounds");
                        break;
                }
            }
        )(value);
    });
}

@nogc
private void defaultFormatterSegmentHandler(ResultT, ParamT)(scope ref ResultT result, const scope FormatSegment segment, scope auto ref ParamT param) nothrow
{
    const formatter = segment.formatter;
    if(formatter.length == 0)
    {
        static if(__traits(compiles, result.put(param)) && !is(ParamT : const bool))
            result.put(param);
        else static if(__traits(compiles, to!String(param)))
            result.put(to!String(param).range);
        else static assert(false, "Don't know how to default format param of type "~ParamT.stringof);
    }
    else
    {
        displayError(raise(
            String("An invalid formatter was passed: ")~String(formatter)
        ));
        assert(false, "An invalid formatter was passed.");
    }
}

@nogc
void formatInfoPusher(scope bcstring format, scope void delegate(SimpleResult!FormatStringInfo info) @nogc nothrow handler) nothrow
{
    size_t start = 0;
    for(size_t cursor = 0; cursor < format.length;)
    {
        const startBracketIndex = format[cursor..$].indexOfAscii('{');
        if(startBracketIndex == INDEX_NOT_FOUND)
        {
            handler(FormatStringInfo(format[start..$]).result);
            return;
        }

        const realStartBracketIndex = cursor+startBracketIndex;
        handler(FormatStringInfo(format[start..realStartBracketIndex]).result); // Push prior chars.
        start = realStartBracketIndex+1;

        // Escaped '{'
        if(start < format.length && format[start] == '{')
        {
            handler(FormatStringInfo(cast(bcstring)"{{").result);
            continue;
        }

        FormatSegment segment;
        bool foundIndex;

        cursor = start;
        Foreach: foreach(i, ch; format[start..$])
        {
            switch(ch)
            {
                case '}':
                    if(!foundIndex)
                    {
                        foundIndex = true;
                        const convResult = format[start..cursor].to!ubyte;
                        if(!convResult.isValid)
                        {
                            handler(raise("Invalid parameter index.").result!FormatStringInfo);
                            return;
                        }
                        segment.formatItemIndex = convResult.value;
                    }
                    else
                    {
                        segment.formatter = format[start..cursor++];
                        break Foreach;
                    }
                    cursor++;
                    break Foreach;

                case ':':
                    if(!foundIndex)
                    {
                        foundIndex = true;
                        const convResult = format[start..cursor].to!ubyte;
                        if(!convResult.isValid)
                        {
                            handler(raise("Invalid parameter index.").result!FormatStringInfo);
                            return;
                        }
                        segment.formatItemIndex = convResult.value;
                        start = cursor+1;
                    } // Assume any extra colons are part of the arguments
                    break;

                default: break;
            }
            cursor++;
        }

        handler(FormatStringInfo(segment).result);
        start = cursor;
    }
}