module libd.datastructures.linkedlist;

import libd.util.errorhandling : onOutOfMemoryError;
import libd.memory;
import libd.memory.ptr;
import libd.algorithm : OptimisationHint;

// "Default" linked list is a double linked list since that's easier for me to implement >xP
@nogc nothrow
@(OptimisationHint.rangeFasterThanIndex)
struct LinkedList(alias T, alias AllocT = SystemAllocator)
{
    static struct Node
    {
        T value;
        Node* next;
        Node* prev;
    }

    private size_t _length;
    private MaybeNullPtr!(Node, AllocT.Tag) _head;
    private MaybeNullPtr!(Node, AllocT.Tag) _tail;
    private AllocatorWrapperOf!AllocT _alloc;

    @disable this(this) {}

    this()(AllocatorWrapperOf!AllocT alloc)
    {
        this._alloc = alloc;
    }

    @nogc nothrow
    ~this()
    {
        while(this._head !is null)
        {
            auto head = this._head;
            this._head = head.next;
            this._alloc.dispose(head);
        }
    }

    alias put = putTail;
    void putTail()(auto ref T value)
    {
        auto node = this._alloc.make!Node(value);
        if(node is null)
            onOutOfMemoryError(null);

        if(this._head is null)
        {
            this._head = node;
            this._tail = node;
        }
        else
        {
            auto tail = this._tail;
            this._tail.next = node;
            node.prev = tail;
            this._tail = node;
        }

        this._length++;
    }

    void putTail(Args...)(scope auto ref Args args)
    {
        foreach(ref value; args)
            this.putTail(value);        
    }

    void moveTail()(auto ref T value)
    {        
        auto node = this._alloc.make!Node();
        if(node is null)
            onOutOfMemoryError(null);
        move(value, node.value);

        if(this._head is null)
        {
            this._head = node;
            this._tail = node;
        }
        else
        {
            auto tail = this._tail;
            this._tail.next = node;
            node.prev = tail;
            this._tail = node;
        }

        this._length++;
    }

    void putHead()(auto ref T value)
    {
        auto node = this._alloc.make!Node(value);
        if(node is null)
            onOutOfMemoryError(null);
        
        if(this._head is null)
        {
            this._head = node;
            this._tail = node;
        }
        else
        {
            auto head = this._head;
            this._head.prev = node;
            node.next = head;
            this._head = node;
        }

        this._length++;
    }

    void insertAt()(size_t index, auto ref T value)
    {
        auto node = this._alloc.make!Node(value);
        if(node is null)
            onOutOfMemoryError(null);

        assert(index <= this._length, "Index out of bounds.");

        if(this._length == 0) // Special case
        {
            this._head = node;
            this._tail = node;
        }
        else if(index == 0) // Special case
        {
            this._head.prev = node;
            node.next = this._head;
            this._head = node;
        }
        else if(index == this._length) // Special case
        {
            this._tail.next = node;
            node.prev = this._tail;
            this._tail = node;
        }
        else
        {
            auto head = this._head;
            foreach(i; 0..index)
                head = head.next;
            assert(head !is null);
            head = head.prev;
            
            auto next = head.next;
            head.next = node;
            node.next = next;
            node.prev = head;
            if(next !is null)
                next.prev = node;
        }

        this._length++;
    }

    alias getAt = getAtHead;
    ref inout(T) getAtHead()(size_t index) inout
    {
        return this.getNodeAtHead(index).value;
    }

    alias removeAt = removeAtHead;
    void removeAtHead()(size_t index, scope ref T dest)
    {
        this.removeAtImpl!getNodeAtHead(index, dest);
    }

    T removeAtHead()(size_t index)
    {
        T value;
        this.removeAtHead(index, value);
        return value;
    }

    void removeAtTail()(size_t index, scope ref T dest)
    {
        this.removeAtImpl!getNodeAtTail(index, dest);
    }

    T removeAtTail()(size_t index)
    {
        T value;
        this.removeAtTail(index, value);
        return value;
    }

    @property @trusted
    auto range() inout
    {
        static struct Range
        {
            Node* node;

            @nogc nothrow:

            bool empty() { return this.node is null; }
            void popFront()
            {
                assert(!this.empty, "Cannot pop an empty range.");
                this.node = this.node.next;
            }
            ref T front()
            {
                assert(!this.empty, "Cannot access front of an empty range.");
                return this.node.value;
            }
        }

        return Range(cast(Node*)this._head.ptr);
    }

    @property @safe
    size_t length() const
    {
        return this._length;
    }

    @safe size_t opDollar() const { return this.length; }
    
    @safe
    ref inout(T) opIndex(size_t index) inout
    {
        return this.getAt(index);
    }

    private void removeAtImpl(alias GetterFunc)(size_t index, scope ref T dest)
    {        
        auto node = GetterFunc(index);
        move(node.value, dest);

        if(this._length == 1)
        {
            this._head = null;
            this._tail = null;
        }
        else if(index == 0)
        {
            if(node.next !is null)
                node.next.prev = null;
            this._head = node.next;
        }
        else if(index == this._length-1)
        {
            if(node.prev !is null)
                node.prev.next = null;
            this._tail = node.prev;
        }
        else
        {
            node.prev.next = node.next;
            node.next.prev = node.prev;
        }

        this._alloc.dispose(node);
        this._length--;
    }

    private inout(Node)* getNodeAtHead()(size_t index) inout
    {
        assert(index < this._length, "Index out of bounds.");

        auto result = cast()this._head.ptr;
        foreach(i; 0..index)
            result = result.next;

        assert(result !is null, "Could not find result?");
        return result;
    }

    private inout(Node)* getNodeAtTail()(size_t index) inout
    {
        assert(index < this._length, "Index out of bounds.");
        
        auto result = cast()this._tail.ptr;
        const iterations = (this._length - index) - 1;
        foreach(i; 0..iterations)
            result = result.prev;
        
        assert(result !is null, "Could not find result?");
        return result;
    }
}
///
@("LinkedList - basic")
unittest
{    
    import libd.algorithm : isCollection, isInputRange;
    import libd.memory    : emplaceInit;
    static assert(isCollection!(LinkedList!int, int));
    static assert(isInputRange!(typeof(LinkedList!int.range())));

    LinkedList!int list;
    
    list.put(2);
    assert(list.length == 1);
    assert(list._head is list._tail);
    assert(list.getAt(0) == 2);
    list.put(4);
    assert(list.length == 2);
    assert(list._head !is list._tail);
    assert(list.getAt(0) == 2);
    assert(list.getAt(1) == 4);
    list.putHead(0);
    assert(list.length == 3);
    assert(list.getAt(0) == 0);
    assert(list.getAt(1) == 2);
    assert(list.getAt(2) == 4);
    list.getAt(1) /= 2;
    assert(list.getAt(1) == 1);
    list.removeAt(1);
    assert(list.length == 2);
    assert(list.getAt(0) == 0);
    assert(list.getAt(1) == 4);
    list.removeAt(0);
    assert(list.length == 1);
    assert(list.getAt(0) == 4);
    assert(list.removeAt(0));
    assert(list.length == 0);
    assert(list._head is list._tail);
    assert(list._head is null);
    list.put(0);
    list.put(0);
    list.put(0);

    int next = 2;
    foreach(ref num; list.range)
    {
        num = next;
        next += 2;
    }
    assert(list[0] == 2);
    assert(list[1] == 4);
    assert(list[2] == 6);
    
    emplaceInit(list);
    list.insertAt(0, 2); // 2
    list.insertAt(0, 0); // 0 2
    list.insertAt(2, 3); // 0 2 3
    list.insertAt(1, 1); // 0 1 2 3
    assert(list.length == 4);
    assert(list[0] == 0);
    assert(list[1] == 1);
    assert(list[2] == 2);
    assert(list[3] == 3);
    assert(list.removeAtTail(1) == 1);
    assert(list.removeAtTail(1) == 2);
    assert(list.removeAtTail(0) == 0);
    assert(list.removeAtTail(0) == 3);
}