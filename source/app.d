version(Testing)
{
    int main(string[])
    {
        import libd.io, libd.console.io;

        static struct S
        {
            int a;
            string b;
        }

        consoleWriteln(consoleRead());

        return 0;
    }
}