/* Minimal GD32VW553 (Nuclei N307) freestanding startup for Klin examples.
 * Polling demos only — no ECLIC vector table. Flash @ 0x08000000.
 */
	.section .text.init, "ax", @progbits
	.globl _start
	.align 2
_start:
	csrci mstatus, 0x8

.option push
.option norelax
	la gp, __global_pointer$
.option pop
	la sp, _eusrstack

	la a0, _data_lma
	la a1, _data_vma
	la a2, _edata
	bgeu a1, a2, 2f
1:
	lw t0, (a0)
	sw t0, (a1)
	addi a0, a0, 4
	addi a1, a1, 4
	bltu a1, a2, 1b
2:
	la a0, _sbss
	la a1, _ebss
	bgeu a0, a1, 2f
1:
	sw zero, (a0)
	addi a0, a0, 4
	bltu a0, a1, 1b
2:
	call main
1:
	j 1b
