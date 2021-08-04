module libd.testing;

public import
    libd.testing.runner;

void testGetLibdCases(ref Array!TestCase cases)
{
    import libd, runtime.system.posix.posix_;

    testGatherCases!(
        libd.async.task,
        libd.async.coroutine,

        libd.algorithm.common,
        libd.algorithm.comparison,
        libd.algorithm.filtering,
        libd.algorithm.mutate,
        libd.algorithm.search,

        libd.console.ansi,
        libd.console.io,

        libd.data.coff_pe,
        libd.data.conv,
        libd.data.format,
        libd.data.hash,

        libd.datastructures.array,
        libd.datastructures.bitkeeper,
        libd.datastructures.growth,
        libd.datastructures.hashstuff,
        libd.datastructures.linkedlist,
        libd.datastructures.mpscqueue,
        libd.datastructures.smartptr,
        libd.datastructures.string,
        libd.datastructures.sumtype,

        libd.io.filesystem,
        libd.io.memory,
        libd.io.stream,

        libd.memory.funcs,
        libd.memory.ptr,
        libd.memory.allocator.blockallocator,
        libd.memory.allocator.common,
        libd.memory.allocator.pageallocator,
        libd.memory.allocator.regionallocator,
        libd.memory.allocator.systemallocator,

        libd.meta.ctassert,
        libd.meta.traits,

        libd.testing.runner,

        libd.threading.atomic,
        libd.threading.canceltoken,
        libd.threading.locks,

        libd.util.bitwise,
        libd.util.cpuid,
        libd.util.errorhandling,
        libd.util.maths,
        libd.util.ternary,

        runtime.system.posix.posix_,
    )(cases);
}