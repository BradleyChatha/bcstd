version(Testing)
{
    int main()
    {
        import libd.io;
        auto result = fileOpen("test.txt", FileOpenMode.createAlways, FileUsage.readWrite);
        result.value.access((scope ref fuckyou) 
        { 
            fuckyou.write("NASIGFOAINSDOFIN"); 
            fuckyou.setPosition(40);
            fuckyou.write("soz");
            fuckyou.setPosition(4);
        });
        ubyte[500] buffer;
        return cast(int)result.value.ptrUnsafe.read(buffer).value;
    }
}