	.file	"matvec.c"
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	matvec
	.type	matvec, @function
matvec:
.LFB39:
	.cfi_startproc
	endbr64
	test	ecx, ecx
	jle	.L19
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	lea	eax, -1[rcx]
	mov	r9, rdx
	mov	rbp, rsp
	.cfi_def_cfa_register 6
	push	r15
	vxorpd	xmm4, xmm4, xmm4
	.cfi_offset 15, -24
	movsx	r15, ecx
	push	r14
	.cfi_offset 14, -32
	lea	r14, 8[rdx+rax*8]
	xor	edx, edx
	push	r13
	.cfi_offset 13, -40
	mov	r13, rax
	mov	eax, ecx
	push	r12
	shr	eax, 2
	lea	r8d, -1[rax]
	inc	r8
	.cfi_offset 12, -48
	mov	r12d, ecx
	push	rbx
	.cfi_offset 3, -56
	sal	r8, 5
	mov	ebx, ecx
	and	r12d, -4
	.p2align 4,,10
	.p2align 3
.L3:
	cmp	r13d, 2
	jbe	.L10
	lea	rcx, [rdi+rdx*8]
	xor	eax, eax
	vmovsd	xmm0, xmm4, xmm4
	.p2align 4,,10
	.p2align 3
.L7:
	vmovupd	ymm5, YMMWORD PTR [rcx+rax]
	vmulpd	ymm1, ymm5, YMMWORD PTR [rsi+rax]
	add	rax, 32
	vaddsd	xmm0, xmm0, xmm1
	vunpckhpd	xmm2, xmm1, xmm1
	vextractf128	xmm1, ymm1, 0x1
	vaddsd	xmm0, xmm0, xmm2
	vaddsd	xmm0, xmm0, xmm1
	vunpckhpd	xmm1, xmm1, xmm1
	vaddsd	xmm0, xmm0, xmm1
	cmp	rax, r8
	jne	.L7
	cmp	r12d, ebx
	je	.L4
	mov	ecx, r12d
	mov	eax, r12d
.L9:
	mov	r10d, ebx
	sub	r10d, ecx
	cmp	r10d, 1
	je	.L5
	vmovupd	xmm1, XMMWORD PTR [rsi+rcx*8]
	lea	r11, [rcx+rdx]
	vmulpd	xmm1, xmm1, XMMWORD PTR [rdi+r11*8]
	mov	ecx, r10d
	and	ecx, -2
	add	eax, ecx
	vaddsd	xmm0, xmm0, xmm1
	vunpckhpd	xmm1, xmm1, xmm1
	vaddsd	xmm0, xmm1, xmm0
	cmp	r10d, ecx
	je	.L4
.L5:
	cdqe
	lea	rcx, [rax+rdx]
	vmovsd	xmm6, QWORD PTR [rdi+rcx*8]
	vfmadd231sd	xmm0, xmm6, QWORD PTR [rsi+rax*8]
.L4:
	vmovsd	QWORD PTR [r9], xmm0
	add	r9, 8
	add	rdx, r15
	cmp	r14, r9
	jne	.L3
	vzeroupper
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	.cfi_remember_state
	.cfi_def_cfa 7, 8
	ret
	.p2align 4,,10
	.p2align 3
.L10:
	.cfi_restore_state
	xor	ecx, ecx
	xor	eax, eax
	vmovsd	xmm0, xmm4, xmm4
	jmp	.L9
.L19:
	.cfi_def_cfa 7, 8
	.cfi_restore 3
	.cfi_restore 6
	.cfi_restore 12
	.cfi_restore 13
	.cfi_restore 14
	.cfi_restore 15
	ret
	.cfi_endproc
.LFE39:
	.size	matvec, .-matvec
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC1:
	.string	"Memory allocation failed.\n"
.LC4:
	.string	"Result y[0] = %f\n"
	.section	.text.startup,"ax",@progbits
	.p2align 4
	.globl	main
	.type	main, @function
main:
.LFB40:
	.cfi_startproc
	endbr64
	lea	r10, 8[rsp]
	.cfi_def_cfa 10, 0
	and	rsp, -32
	push	QWORD PTR -8[r10]
	mov	edi, 33554432
	push	rbp
	mov	rbp, rsp
	.cfi_escape 0x10,0x6,0x2,0x76,0
	push	r14
	push	r13
	push	r12
	push	r10
	.cfi_escape 0xf,0x3,0x76,0x60,0x6
	.cfi_escape 0x10,0xe,0x2,0x76,0x78
	.cfi_escape 0x10,0xd,0x2,0x76,0x70
	.cfi_escape 0x10,0xc,0x2,0x76,0x68
	sub	rsp, 16
	call	malloc@PLT
	mov	edi, 16384
	mov	r13, rax
	call	malloc@PLT
	mov	esi, 1
	mov	edi, 16384
	mov	r12, rax
	call	calloc@PLT
	test	r13, r13
	mov	r14, rax
	sete	al
	test	r12, r12
	sete	dl
	or	al, dl
	jne	.L32
	test	r14, r14
	je	.L32
	vmovapd	ymm0, YMMWORD PTR .LC2[rip]
	mov	rdx, r13
	lea	rcx, 33554432[r13]
	mov	rax, r13
	.p2align 4,,10
	.p2align 3
.L27:
	vmovupd	YMMWORD PTR [rax], ymm0
	add	rax, 32
	cmp	rax, rcx
	jne	.L27
	vmovapd	ymm0, YMMWORD PTR .LC3[rip]
	mov	rax, r12
	lea	rsi, 16384[r12]
	.p2align 4,,10
	.p2align 3
.L28:
	vmovupd	YMMWORD PTR [rax], ymm0
	add	rax, 32
	cmp	rsi, rax
	jne	.L28
	mov	rsi, r14
	vxorpd	xmm4, xmm4, xmm4
	.p2align 4,,10
	.p2align 3
.L29:
	xor	eax, eax
	vmovsd	xmm2, xmm4, xmm4
	.p2align 4,,10
	.p2align 3
.L30:
	vmovupd	ymm5, YMMWORD PTR [r12+rax]
	vmulpd	ymm0, ymm5, YMMWORD PTR [rdx+rax]
	add	rax, 32
	vaddsd	xmm2, xmm0, xmm2
	vunpckhpd	xmm1, xmm0, xmm0
	vextractf128	xmm0, ymm0, 0x1
	vaddsd	xmm1, xmm1, xmm2
	vaddsd	xmm2, xmm0, xmm1
	vunpckhpd	xmm0, xmm0, xmm0
	vaddsd	xmm2, xmm2, xmm0
	cmp	rax, 16384
	jne	.L30
	add	rdx, 16384
	vmovsd	QWORD PTR [rsi], xmm2
	add	rsi, 8
	cmp	rcx, rdx
	jne	.L29
	vmovsd	xmm0, QWORD PTR [r14]
	lea	rsi, .LC4[rip]
	mov	edi, 1
	mov	eax, 1
	vzeroupper
	call	__printf_chk@PLT
	mov	rdi, r13
	call	free@PLT
	mov	rdi, r12
	call	free@PLT
	mov	rdi, r14
	call	free@PLT
	xor	eax, eax
.L23:
	add	rsp, 16
	pop	r10
	.cfi_remember_state
	.cfi_def_cfa 10, 0
	pop	r12
	pop	r13
	pop	r14
	pop	rbp
	lea	rsp, -8[r10]
	.cfi_def_cfa 7, 8
	ret
.L32:
	.cfi_restore_state
	mov	rcx, QWORD PTR stderr[rip]
	mov	edx, 26
	mov	esi, 1
	lea	rdi, .LC1[rip]
	call	fwrite@PLT
	mov	eax, 1
	jmp	.L23
	.cfi_endproc
.LFE40:
	.size	main, .-main
	.section	.rodata.cst32,"aM",@progbits,32
	.align 32
.LC2:
	.long	0
	.long	1072693248
	.long	0
	.long	1072693248
	.long	0
	.long	1072693248
	.long	0
	.long	1072693248
	.align 32
.LC3:
	.long	0
	.long	1073741824
	.long	0
	.long	1073741824
	.long	0
	.long	1073741824
	.long	0
	.long	1073741824
	.ident	"GCC: (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 8
	.long	1f - 0f
	.long	4f - 1f
	.long	5
0:
	.string	"GNU"
1:
	.align 8
	.long	0xc0000002
	.long	3f - 2f
2:
	.long	0x3
3:
	.align 8
4:
