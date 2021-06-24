SECTION text

global bcstdCoroutineSwap

; %1 = Register containing pointer to RawCoroutine
%macro saveRoutine 1
    %ifdef win64
        lea rax, [rsp+8] ; This is the stack pointer for the CALLER
        mov r8, [rsp]    ; Return address should be the only thing on the stack.
        mov r9, gs:[0]   ; TIB stuff
        mov r10, gs:[8]  ; ^
        mov r11, gs:[16] ; ^
        mov [%1+8*0], rax
        mov [%1+8*1], r8
        mov [%1+8*2], r12
        mov [%1+8*3], r13
        mov [%1+8*4], r14
        mov [%1+8*5], r15
        mov [%1+8*6], rdi
        mov [%1+8*7], rsi
        mov [%1+8*8], rbx
        mov [%1+8*9], rbp
        mov [%1+8*10], r9
        mov [%1+8*11], r10
        mov [%1+8*12], r11
    %elifdef sysv
        lea rax, [rsp+8]
        mov r8, [rsp]
        mov [%1+8*0] rax
        mov [%1+8*1] r8
        mov [%1+8*2] rbx
        mov [%1+8*3] rbp
        mov [%1+8*4] r12
        mov [%1+8*5] r13
        mov [%1+8*6] r14
        mov [%1+8*7] r15
    %else
        %error "win64 and sysv are both undefined."
    %endif
%endmacro

%macro restoreRoutine 1
    %ifdef win64
        mov rsp, [%1+8*0]
        mov rax, [%1+8*1]
        mov r12, [%1+8*2]
        mov r13, [%1+8*3]
        mov r14, [%1+8*4]
        mov r15, [%1+8*5]
        mov rdi, [%1+8*6]
        mov rsi, [%1+8*7]
        mov rbx, [%1+8*8]
        mov rbp, [%1+8*9]
        mov r8,  [%1+8*10]
        mov r9,  [%1+8*11]
        mov r10, [%1+8*12]
        mov gs:[0], r8
        mov gs:[8], r9
        mov gs:[16], r10
        jmp rax
    %elifdef sysv
    %else
        %error "win64 and sysv are both undefined."
    %endif
%endmacro

; (ref RawCoroutine thisRoutine, ref RawCoroutine newRoutine)
bcstdCoroutineSwap:
    saveRoutine PARAM_REG_0
    restoreRoutine PARAM_REG_1
    int3 ; Failsafe
    hlt