module libd.memory.allocator._test;

package:
import libd.memory.allocator;

void basicAllocatorTests(alias AllocT, alias Ctor)()
{
    alias Alloc = Allocator!AllocT;

    basicSimpleMakeAndDispose!(Alloc, Ctor)();
}

private void basicSimpleMakeAndDispose(alias Alloc, alias Ctor)()
{
    int ctor;
    int dtor;

    static struct S
    {
        int* dtor;

        @nogc nothrow:
        this(int* ctor, int* dtor)
        {
            (*ctor)++;
            this.dtor = dtor;
        }

        ~this()
        {
            if(this.dtor !is null)
                (*this.dtor)++;
        }
    }

    auto alloc = Alloc(Ctor());
    auto ptr = alloc.make!S(&ctor, &dtor);
    assert(ptr !is null);
    alloc.dispose(ptr);
    assert(ptr is null);
    assert(ctor == 1);
    assert(dtor == 1);
}