; This file is generated by tools/cpuidgen.d
SECTION .text
global cpuidPopulateStore
struc cpustore
    .idString: resb 12
    .maxLeaf: resb 4
    .eax1_eax: resb 4
    .eax1_ebx: resb 4
    .eax1_ecx: resb 4
    .eax1_edx: resb 4
    .eax7ecx0_ebx: resb 4
    .eax7ecx0_ecx: resb 4
    .eax7ecx0_edx: resb 4
endstruc
cpuidPopulateStore:
    ; maxLeaf & idString
    mov r10, PARAM_REG_0
    xor eax, eax
    xor ecx, ecx
    cpuid
    mov [r10+cpustore.maxLeaf], eax
    mov [r10+cpustore.idString+0], ebx
    mov [r10+cpustore.idString+4], edx
    mov [r10+cpustore.idString+8], ecx
    ; eax1_eax - eax - CpuIdLeaf(1, 0)
    mov eax, [r10+cpustore.maxLeaf]
    cmp eax, [r10+cpustore.maxLeaf]
    jc .skip_eax1_eax
    mov eax, 1
    mov ecx, 0
    cpuid
    mov [r10+cpustore.eax1_eax], eax
.skip_eax1_eax:
    ; eax1_ebx - ebx - CpuIdLeaf(1, 0)
    mov eax, [r10+cpustore.maxLeaf]
    cmp eax, [r10+cpustore.maxLeaf]
    jc .skip_eax1_ebx
    mov eax, 1
    mov ecx, 0
    cpuid
    mov [r10+cpustore.eax1_ebx], ebx
.skip_eax1_ebx:
    ; eax1_ecx - ecx - CpuIdLeaf(1, 0)
    mov eax, [r10+cpustore.maxLeaf]
    cmp eax, [r10+cpustore.maxLeaf]
    jc .skip_eax1_ecx
    mov eax, 1
    mov ecx, 0
    cpuid
    mov [r10+cpustore.eax1_ecx], ecx
.skip_eax1_ecx:
    ; eax1_edx - edx - CpuIdLeaf(1, 0)
    mov eax, [r10+cpustore.maxLeaf]
    cmp eax, [r10+cpustore.maxLeaf]
    jc .skip_eax1_edx
    mov eax, 1
    mov ecx, 0
    cpuid
    mov [r10+cpustore.eax1_edx], edx
.skip_eax1_edx:
    ; eax7ecx0_ebx - ebx - CpuIdLeaf(7, 0)
    mov eax, [r10+cpustore.maxLeaf]
    cmp eax, [r10+cpustore.maxLeaf]
    jc .skip_eax7ecx0_ebx
    mov eax, 7
    mov ecx, 0
    cpuid
    mov [r10+cpustore.eax7ecx0_ebx], ebx
.skip_eax7ecx0_ebx:
    ; eax7ecx0_ecx - ecx - CpuIdLeaf(7, 0)
    mov eax, [r10+cpustore.maxLeaf]
    cmp eax, [r10+cpustore.maxLeaf]
    jc .skip_eax7ecx0_ecx
    mov eax, 7
    mov ecx, 0
    cpuid
    mov [r10+cpustore.eax7ecx0_ecx], ecx
.skip_eax7ecx0_ecx:
    ; eax7ecx0_edx - edx - CpuIdLeaf(7, 0)
    mov eax, [r10+cpustore.maxLeaf]
    cmp eax, [r10+cpustore.maxLeaf]
    jc .skip_eax7ecx0_edx
    mov eax, 7
    mov ecx, 0
    cpuid
    mov [r10+cpustore.eax7ecx0_edx], edx
.skip_eax7ecx0_edx:
    ret