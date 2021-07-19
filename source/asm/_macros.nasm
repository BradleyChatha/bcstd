; self-note: Remember that relying on these won't always work due to ABI differences.
;            SysV has an extra parameter register, the register allocation for mixed int and FLU parameter registers is also different.
;            So some functions can be written in a platform-agnostic way, but some functions need specific `%ifdef sysv` and such extra logic in place.
%ifdef win64
    %define PARAM_REG_0 rcx
    %define PARAM_REG_1 rdx
    %define PARAM_REG_2 r8
    %define PARAM_REG_3 r9
    %define VOLATILE_NONPARAM_REG_0 r10
    %define VOLATILE_NONPARAM_REG_1 r11

    %define PARAM_REG8_0 cl
    %define PARAM_REG8_1 dl
    %define PARAM_REG8_2 r8b
    %define PARAM_REG8_3 r9b
    %define VOLATILE_NONPARAM_REG8_0 r10b
    %define VOLATILE_NONPARAM_REG8_1 r11b

    %define PARAM_REG16_0 cx
    %define PARAM_REG16_1 dx
    %define PARAM_REG16_2 r8w
    %define PARAM_REG16_3 r9w
    %define VOLATILE_NONPARAM_REG16_0 r10w
    %define VOLATILE_NONPARAM_REG16_1 r11w

    %define PARAM_REG32_0 ecx
    %define PARAM_REG32_1 edi
    %define PARAM_REG32_2 r8d
    %define PARAM_REG32_3 r9d
    %define VOLATILE_NONPARAM_REG32_0 r10d
    %define VOLATILE_NONPARAM_REG32_1 r11d
%elifdef sysv
    %define PARAM_REG_0 rdi
    %define PARAM_REG_1 rsi
    %define PARAM_REG_2 rdx
    %define PARAM_REG_3 rcx
    %define VOLATILE_NONPARAM_REG_0 r10
    %define VOLATILE_NONPARAM_REG_1 r11

    %define PARAM_REG8_0 dil
    %define PARAM_REG8_1 sil
    %define PARAM_REG8_2 dl
    %define PARAM_REG8_3 cl
    %define VOLATILE_NONPARAM_REG8_0 r10b
    %define VOLATILE_NONPARAM_REG8_1 r11b

    %define PARAM_REG16_0 di
    %define PARAM_REG16_1 si
    %define PARAM_REG16_2 di
    %define PARAM_REG16_3 ci
    %define VOLATILE_NONPARAM_REG16_0 r10w
    %define VOLATILE_NONPARAM_REG16_1 r11w

    %define PARAM_REG32_0 edi
    %define PARAM_REG32_1 esi
    %define PARAM_REG32_2 edx
    %define PARAM_REG32_3 ecx
    %define VOLATILE_NONPARAM_REG32_0 r10d
    %define VOLATILE_NONPARAM_REG32_1 r11d
%endif