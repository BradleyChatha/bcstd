SECTION .text

global indexOfByteAvx2

; ulong indexOfByteAvx2(const(char)* haystack, ulong haystackSize, char* needle, ulong* remainingChars)
indexOfByteAvx2:
    ; Vars
    ;   ymm0                    = needle as mask
    ;   ymm1                    = Result of next 32 chars & ymm0
    ;   rax                     = return value + temp calcs
    ;   VOLATILE_NONPARAM_REG_0 = amount of blocks of 32 we can read, used as the loop counter
    ;   PARAM_REG_3             = No longer needed after a certain point, so stores the starting pointer of haystack.

    vpbroadcastb ymm1, byte [PARAM_REG_2]
    vmovdqu      ymm0, ymm1

    mov VOLATILE_NONPARAM_REG_0, PARAM_REG_1
    shr VOLATILE_NONPARAM_REG_0, 5 ; / 32
    test VOLATILE_NONPARAM_REG_0, VOLATILE_NONPARAM_REG_0
    jz .end

    mov rax, [PARAM_REG_3]
    and rax, 31 ; % 32
    mov [PARAM_REG_3], rax
    mov PARAM_REG_3, PARAM_REG_0

.loop:
    vpcmpeqb  ymm1, ymm0, [PARAM_REG_0]
    vpmovmskb rax, ymm1
    test      rax, rax
    jz        .continue

    ; Loop counter is no longer needed, so we can also use that for some calcs
    sub   PARAM_REG_0,             PARAM_REG_3 ; currentPtr -= startPtr
    tzcnt VOLATILE_NONPARAM_REG_0, rax
    add   PARAM_REG_0,             VOLATILE_NONPARAM_REG_0
    mov   rax,                     PARAM_REG_0
    ret

.continue:
    add PARAM_REG_0, 32
    dec VOLATILE_NONPARAM_REG_0
    jnz .loop

.end:
    mov rax, -1
    ret