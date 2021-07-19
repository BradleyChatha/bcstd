SECTION .text

global atomicCas8
global atomicCas16
global atomicCas32
global atomicCas64

global atomicStore8
global atomicStore16
global atomicStore32
global atomicStore64

global atomicLoad8
global atomicLoad16
global atomicLoad32
global atomicLoad64

%macro gen_cas 4
    mov %1, %3                          ; a = equalsThis
    lock cmpxchg %2 [PARAM_REG_0], %4   ; if(*ifThis == equalsThis) *ifThis = setThis
    xor rax, rax
    setz al
    ret
%endmacro

%macro gen_store 2
    lock xchg [%1], %2
    ret
%endmacro

%macro gen_load 2
    xor %1, %1
    lock xadd [%2], %1
    ret
%endmacro

atomicCas8:
    gen_cas al, byte, PARAM_REG8_1, PARAM_REG8_2
atomicCas16:
    gen_cas ax, word, PARAM_REG16_1, PARAM_REG16_2
atomicCas32:
    gen_cas eax, dword, PARAM_REG32_1, PARAM_REG32_2
atomicCas64:
    gen_cas rax, qword, PARAM_REG_1, PARAM_REG_2

atomicStore8:
    gen_store PARAM_REG_0, PARAM_REG8_1
atomicStore16:
    gen_store PARAM_REG_0, PARAM_REG16_1
atomicStore32:
    gen_store PARAM_REG_0, PARAM_REG32_1
atomicStore64:
    gen_store PARAM_REG_0, PARAM_REG_1

atomicLoad8:
    gen_load al, PARAM_REG_0
atomicLoad16:
    gen_load ax, PARAM_REG_0
atomicLoad32:
    gen_load eax, PARAM_REG_0
atomicLoad64:
    gen_load rax, PARAM_REG_0