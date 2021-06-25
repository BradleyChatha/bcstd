module bcstd.data.format;

import bcstd.datastructures.string, bcstd.object, bcstd.datastructures.sumtype, bcstd.datastructures.array,
       bcstd.algorithm.search, bcstd.util.errorhandling, bcstd.data.conv;

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
                            auto formatter = segment.formatter;
                            if(formatter is null)
                            {
                                static if(is(Params[i] : bcstring) || is(Params[i] == String))
                                    result.put(params[i]);
                                else static if(__traits(compiles, to!String(params[i])))
                                    result.put(to!String(params[i]).range);
                                else static if(__traits(hasMember, Params[i], "toString"))
                                {
                                    auto str = params[i].toString();
                                    result.put(str);
                                }
                                else static assert(false, "Don't know how to default format param of type "~Params[i].stringof);
                            }
                            else
                                assert(false, "TODO");
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

    if(throwError)
        return error.result!String;

    return result.result;
}
///
@("format (formatInfoPusher by proxy)")
unittest
{
    //assert(format("abc").assumeValid == "abc");
    assert(format("abc {1} {0}", 123, "easy as").assumeValid == "abc easy as 123");
}

alias f = format!bcstring;

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
            start++;
            cursor = start;
            continue;
        }

        FormatSegment segment;
        bool foundIndex;
        bool foundFormatter; // TODO:

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
                    cursor++;
                    break Foreach;

                default: break;
            }
            cursor++;
        }

        handler(FormatStringInfo(segment).result);
        start = cursor;
    }
}