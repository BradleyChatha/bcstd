version(Testing)
{
    int main(string[])
    {
        import libd.io, libd.console.io, libd.data.coff_pe;

        auto bytes = fsRead("./libd.exe").assumeValid;
        auto coff = coffpeParseHeader((*bytes.ptrUnsafe)[0..$]);
        if(!coff.isValid)
        {
            displayError(coff.error);
            return -1;
        }

        consoleWriteln(coff.value);
        foreach(section; coff.value.sectionTables.ptrUnsafe.range)
            consoleWriteln(section);
        return 0;
    }
}