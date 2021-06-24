nasm -o ../../dep/bcstd_win64.obj -Wall -Ox -f win64 -Dwin64 lib.nasm
nasm -o ../../dep/bcstd_sysv.obj -Wall -Ox -f elf64 -Dsysv lib.nasm