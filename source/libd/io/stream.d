module libd.io.stream;

enum isStream(alias Stream) =
    is(Stream == struct)
 && __traits(hasMember, Stream, "write")
 && __traits(hasMember, Stream, "read")
 && __traits(hasMember, Stream, "hasData")
 && __traits(hasMember, Stream, "isOpen")
 && __traits(hasMember, Stream, "getPosition")
 && __traits(hasMember, Stream, "setPosition")
 && __traits(hasMember, Stream, "getSize")
 && __traits(hasMember, Stream, "canPosition")
 && __traits(hasMember, Stream, "canWrite")
 && __traits(hasMember, Stream, "canRead");