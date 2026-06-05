.section .text

.extern kmain

.globl _start
.type _start, @function
_start:
    # Limine passes boot info pointer in RDI
    # System V ABI: first argument = RDI

    # optionally preserve it or pass it through
    mov %rdi, %rdi

    # call C kernel entry
    call kmain

.hang:
    hlt
    jmp .hang