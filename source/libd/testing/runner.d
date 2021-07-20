module libd.testing.runner;

import libd.datastructures.smartptr;

@nogc nothrow:

private alias TestCaseFunc = void function();
__gshared bool g_testRunnerRunning;

struct TestCase
{
    string name;
    TestCaseFunc func;
}

void testGatherCases(Modules...)(ref Array!TestCase cases)
{
    static foreach(i; 0..Modules.length)
        appendCases!(Modules[i])(cases);
}

private void appendCases(alias Aggregate)(ref Array!TestCase cases)
{
    static if(__traits(compiles, __traits(getUnitTests, Aggregate)))
    foreach(test; __traits(getUnitTests, Aggregate))
    {{
        string name = __traits(identifier, test);

        static foreach(attrib; __traits(getAttributes, test))
        {
            static if(is(typeof(attrib) == string))
                name = attrib;
        }

        cases.put(TestCase(name, cast(TestCaseFunc)&test)); // We compile under -betterC, @nogc nothrow is a complete guarentee because we also killed DRuntime
    }}

    static if(!__traits(isModule, Aggregate))
    static if(__traits(compiles, __traits(allMembers, Aggregate)))
    static foreach(memberName; __traits(allMembers, Aggregate))
    {{
        alias Member = __traits(getMember, Aggregate, memberName);
        static if(__traits(compiles, appendCases!Member(cases)))
            appendCases!Member(cases);
    }}
}

void testRunner(const bcstring[] args, ref const Array!TestCase cases)
{
    import libd.console, libd.async, libd.algorithm;
    g_testRunnerRunning = true;
    scope(exit) g_testRunnerRunning = false;

    enum Result
    {
        FAILSAFE,
        success,
        failure
    }

    static struct TestResult
    {
        TestCase test;
        Result result;
        BcError error;
    }

    Task testTask;
    Array!TestResult results;
    foreach(test; cases)
    {
        consoleWritefln("{0}{1}", "Running: ".ansi.fg(Ansi4BitColour.magenta), test.name);
        // `assert` has special behaviour when we set g_testRunnerRunning.
        // It expects unittests to be ran inside of a task, so it can then kill the task off and
        // return an error, instead of killing the program off completely.
        taskRun(testTask, (){
            taskAccessContext!(const(TestCase)*, (scope ref test)
            {
                test.func();
            });
        }, &test);

        if(testTask.hasError)
            results.put(TestResult(test, Result.failure, testTask.error));
        else
            results.put(TestResult(test, Result.success));
    }

    consoleWriteln("\n\nThe following tests were successful:".ansi.fg(Ansi4BitColour.green));
    foreach(pass; results.range.where!(test => test.result == Result.success))
        consoleWriteln('\t', pass.test.name.ansi.fg(Ansi4BitColour.green));

    consoleWriteln("\n\nThe following tests failed:".ansi.fg(Ansi4BitColour.red));
    foreach(fail; results.range.where!(test => test.result == Result.failure))
    {
        consoleWriteln('\t', fail.test.name.ansi.fg(Ansi4BitColour.red));
        displayError(fail.error);
    }
}