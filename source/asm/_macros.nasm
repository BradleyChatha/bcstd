%ifdef win64
    %define PARAM_REG_0 rcx
    %define PARAM_REG_1 rdx
    %define PARAM_REG_2 r8
    %define PARAM_REG_3 r9
    %define VOLATILE_NONPARAM_REG_0 r10
    %define VOLATILE_NONPARAM_REG_1 r11
%elifdef sysv
    %define PARAM_REG_0 rdi
    %define PARAM_REG_1 rsi
    %define PARAM_REG_2 rdx
    %define PARAM_REG_3 rcx
    %define VOLATILE_NONPARAM_REG_0 r10
    %define VOLATILE_NONPARAM_REG_1 r11
%endif