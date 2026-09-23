	.file	"lab3.cpp"
	.text
#APP
	.globl _ZSt21ios_base_library_initv
#NO_APP
	.p2align 4
	.globl	_Z16timespec_diff_nsPK8timespecS1_
	.type	_Z16timespec_diff_nsPK8timespecS1_, @function
_Z16timespec_diff_nsPK8timespecS1_:
.LFB3383:
	.cfi_startproc
	movq	(%rdi), %rax
	subq	(%rsi), %rax
	imulq	$1000000000, %rax, %rax
	addq	8(%rdi), %rax
	subq	8(%rsi), %rax
	ret
	.cfi_endproc
.LFE3383:
	.size	_Z16timespec_diff_nsPK8timespecS1_, .-_Z16timespec_diff_nsPK8timespecS1_
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align 8
.LC0:
	.string	"clock_gettime(CLOCK_MONOTONIC_RAW)"
	.text
	.p2align 4
	.globl	_Z16timing_tool_namev
	.type	_Z16timing_tool_namev, @function
_Z16timing_tool_namev:
.LFB3387:
	.cfi_startproc
	movl	$.LC0, %eax
	ret
	.cfi_endproc
.LFE3387:
	.size	_Z16timing_tool_namev, .-_Z16timing_tool_namev
	.section	.rodata.str1.8
	.align 8
.LC1:
	.string	"\nMeasuring clock_gettime(CLOCK_MONOTONIC_RAW) overhead...\n"
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC2:
	.string	"Iterations: %d\n"
.LC3:
	.string	"Average latency: %lld ns\n"
.LC4:
	.string	"Minimum latency: %lld ns\n"
.LC5:
	.string	"Maximum latency: %lld ns\n"
	.text
	.p2align 4
	.globl	_Z23measure_timing_overheadv
	.type	_Z23measure_timing_overheadv, @function
_Z23measure_timing_overheadv:
.LFB3388:
	.cfi_startproc
	pushq	%r13
	.cfi_def_cfa_offset 16
	.cfi_offset 13, -16
	movl	$.LC1, %edi
	movq	$-1, %r13
	pushq	%r12
	.cfi_def_cfa_offset 24
	.cfi_offset 12, -24
	xorl	%r12d, %r12d
	pushq	%rbp
	.cfi_def_cfa_offset 32
	.cfi_offset 6, -32
	xorl	%ebp, %ebp
	pushq	%rbx
	.cfi_def_cfa_offset 40
	.cfi_offset 3, -40
	movl	$100000, %ebx
	subq	$40, %rsp
	.cfi_def_cfa_offset 80
	call	puts
	jmp	.L6
	.p2align 4,,10
	.p2align 3
.L5:
	cmpq	%rax, %r12
	cmovl	%rax, %r12
	subl	$1, %ebx
	je	.L10
.L6:
	movq	%rsp, %rsi
	movl	$4, %edi
	call	clock_gettime
	leaq	16(%rsp), %rsi
	movl	$4, %edi
	call	clock_gettime
	movq	16(%rsp), %rax
	subq	(%rsp), %rax
	imulq	$1000000000, %rax, %rax
	addq	24(%rsp), %rax
	subq	8(%rsp), %rax
	addq	%rax, %rbp
	cmpq	$-1, %r13
	je	.L7
	cmpq	%r13, %rax
	jge	.L5
.L7:
	cmpq	%rax, %r12
	movq	%rax, %r13
	cmovl	%rax, %r12
	subl	$1, %ebx
	jne	.L6
.L10:
	movl	$100000, %esi
	movl	$.LC2, %edi
	xorl	%eax, %eax
	call	printf
	movl	$.LC3, %edi
	movabsq	$3022314549036572937, %rax
	imulq	%rbp
	sarq	$63, %rbp
	xorl	%eax, %eax
	sarq	$14, %rdx
	subq	%rbp, %rdx
	movq	%rdx, %rsi
	call	printf
	movq	%r13, %rsi
	movl	$.LC4, %edi
	xorl	%eax, %eax
	call	printf
	movq	%r12, %rsi
	movl	$.LC5, %edi
	xorl	%eax, %eax
	call	printf
	addq	$40, %rsp
	.cfi_def_cfa_offset 40
	xorl	%eax, %eax
	popq	%rbx
	.cfi_def_cfa_offset 32
	popq	%rbp
	.cfi_def_cfa_offset 24
	popq	%r12
	.cfi_def_cfa_offset 16
	popq	%r13
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3388:
	.size	_Z23measure_timing_overheadv, .-_Z23measure_timing_overheadv
	.p2align 4
	.globl	_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i
	.type	_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i, @function
_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i:
.LFB3389:
	.cfi_startproc
	movl	%ecx, %eax
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	imull	%ecx, %eax
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	movq	%rdx, %r14
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	movq	%rdi, %r12
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	movq	%rsi, %rbp
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	movl	%ecx, %ebx
	subq	$40, %rsp
	.cfi_def_cfa_offset 96
	testl	%eax, %eax
	je	.L12
	cltq
	leaq	0(,%rax,8), %r13
	movq	%r13, %rdi
	call	_Znwm
	movq	%r13, %rdx
	xorl	%esi, %esi
	leaq	(%rax,%r13), %rcx
	movq	%rax, (%r12)
	movq	%rax, %rdi
	movq	%rax, %r15
	movq	%rcx, 16(%r12)
	movq	%rcx, (%rsp)
	call	memset
	movq	(%rsp), %rcx
.L23:
	movq	%rcx, 8(%r12)
	testl	%ebx, %ebx
	jle	.L11
	movq	0(%rbp), %rax
	movslq	%ebx, %r10
	movq	(%r14), %r13
	movl	%ebx, %esi
	salq	$3, %r10
	movq	%r15, 16(%rsp)
	shrl	%esi
	movl	%ebx, %r14d
	addq	%r10, %rax
	movq	%r12, 24(%rsp)
	movq	%r15, %rdx
	xorl	%r11d, %r11d
	movq	%rax, %rbp
	leaq	8(%r13), %rax
	xorl	%ecx, %ecx
	salq	$4, %rsi
	movq	%rax, 8(%rsp)
	andl	$-2, %r14d
	.p2align 4
	.p2align 3
.L14:
	movq	16(%rsp), %r12
	leal	(%r11,%r14), %r15d
	movl	%ecx, (%rsp)
	movq	%rbp, %rdi
	movslq	%r15d, %r15
	movq	8(%rsp), %r8
	subq	%r10, %rdi
	movq	%r13, %rax
	xorl	%r9d, %r9d
	leaq	(%r12,%r15,8), %r15
.L22:
	movsd	(%rdi), %xmm2
	cmpl	$1, %ebx
	je	.L15
	cmpq	%rdx, %r8
	je	.L15
.L38:
	movapd	%xmm2, %xmm1
	xorl	%ecx, %ecx
	unpcklpd	%xmm1, %xmm1
	.p2align 5
	.p2align 4
	.p2align 3
.L16:
	movupd	(%rax,%rcx), %xmm0
	movupd	(%rdx,%rcx), %xmm3
	mulpd	%xmm1, %xmm0
	addpd	%xmm3, %xmm0
	movups	%xmm0, (%rdx,%rcx)
	addq	$16, %rcx
	cmpq	%rsi, %rcx
	jne	.L16
	testb	$1, %bl
	je	.L17
	leal	(%r14,%r9), %ecx
	movslq	%ecx, %rcx
	mulsd	0(%r13,%rcx,8), %xmm2
	addsd	(%r15), %xmm2
	movsd	%xmm2, (%r15)
.L17:
	addq	$8, %rdi
	cmpq	%rbp, %rdi
	je	.L35
	addq	%r10, %r8
	movsd	(%rdi), %xmm2
	addq	%r10, %rax
	addl	%ebx, %r9d
	cmpq	%rdx, %r8
	jne	.L38
.L15:
	leaq	(%rax,%r10), %r12
	movq	%rdx, %rcx
	.p2align 5
	.p2align 4
	.p2align 3
.L18:
	movsd	(%rax), %xmm0
	addq	$8, %rax
	addq	$8, %rcx
	mulsd	%xmm2, %xmm0
	addsd	-8(%rcx), %xmm0
	movsd	%xmm0, -8(%rcx)
	cmpq	%r12, %rax
	jne	.L18
	addq	$8, %rdi
	addl	%ebx, %r9d
	addq	%r10, %r8
	cmpq	%rbp, %rdi
	jne	.L22
	.p2align 4
	.p2align 3
.L35:
	movl	(%rsp), %ecx
	addq	%r10, %rbp
	addq	%r10, %rdx
	addl	%ebx, %r11d
	addl	$1, %ecx
	cmpl	%ecx, %ebx
	jne	.L14
	movq	24(%rsp), %r12
.L11:
	addq	$40, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	movq	%r12, %rax
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
.L12:
	.cfi_restore_state
	movq	$0, (%rdi)
	xorl	%r15d, %r15d
	xorl	%ecx, %ecx
	movq	$0, 16(%rdi)
	jmp	.L23
	.cfi_endproc
.LFE3389:
	.size	_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i, .-_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i
	.section	.rodata.str1.8
	.align 8
.LC8:
	.string	"\nMatrix multiplication benchmark\n"
	.align 8
.LC9:
	.string	"--------------------------------\n"
	.section	.rodata.str1.1
.LC10:
	.string	"Matrix size: "
.LC11:
	.string	" x "
.LC12:
	.string	"\n"
.LC13:
	.string	"Iterations:  "
.LC14:
	.string	"Timer:       "
	.section	.rodata.str1.8
	.align 8
.LC15:
	.string	"cannot create std::vector larger than max_size()"
	.section	.rodata.str1.1
.LC17:
	.string	"Iteration "
.LC18:
	.string	": "
.LC19:
	.string	" ns ("
.LC21:
	.string	" s)\n"
.LC22:
	.string	"Results: "
.LC23:
	.string	"Average: "
.LC24:
	.string	"Minimum: "
.LC25:
	.string	"Maximum: "
.LC26:
	.string	"Variance: "
.LC27:
	.string	" ns^2\n"
.LC28:
	.string	"Std dev: "
.LC29:
	.string	"\nChecksum: "
.LC30:
	.string	","
	.section	.text.unlikely,"ax",@progbits
.LCOLDB31:
	.text
.LHOTB31:
	.p2align 4
	.globl	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE
	.type	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE, @function
_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE:
.LFB3403:
	.cfi_startproc
	.cfi_personality 0x3,__gxx_personality_v0
	.cfi_lsda 0x3,.LLSDA3403
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	movq	%rsi, %r15
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	movq	%rdi, %r12
	movl	$_ZSt4cout, %edi
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$248, %rsp
	.cfi_def_cfa_offset 304
	movq	%rsi, 56(%rsp)
	movl	$.LC8, %esi
	movq	%rdx, 104(%rsp)
	movl	$33, %edx
.LEHB0:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$33, %edx
	movl	$.LC9, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$13, %edx
	movl	$.LC10, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r12, %rsi
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$3, %edx
	movl	$.LC11, %esi
	movq	%rax, %rbx
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r12, %rsi
	movq	%rbx, %rdi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$1, %edx
	movl	$.LC12, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$13, %edx
	movl	$.LC13, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r15, %rsi
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$1, %edx
	movl	$.LC12, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$13, %edx
	movl	$.LC14, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$34, %edx
	movl	$.LC0, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$1, %edx
	movl	$.LC12, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$1, %edx
	movl	$.LC12, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r12, %rax
	imulq	%r12, %rax
	movq	%rax, 80(%rsp)
	shrq	$60, %rax
	jne	.L115
	cmpq	$0, 80(%rsp)
	je	.L121
	movq	80(%rsp), %rbx
	leaq	0(,%rbx,8), %rbp
	movq	%rbp, %rdi
	call	_Znwm
.LEHE0:
	movq	%rax, 88(%rsp)
	movq	%rax, 112(%rsp)
	movq	$0x000000000, (%rax)
	cmpq	$1, %rbx
	je	.L122
	leaq	8(%rax), %rdi
	leaq	-8(%rbp), %rdx
	xorl	%esi, %esi
	call	memset
	movq	%rbp, %rdi
.LEHB1:
	call	_Znwm
.LEHE1:
	leaq	8(%rax), %rdi
	leaq	-8(%rbp), %rdx
	xorl	%esi, %esi
	movq	%rax, 96(%rsp)
	movq	$0x000000000, (%rax)
	movq	%rax, 144(%rsp)
	call	memset
.L47:
	movq	%rbp, 80(%rsp)
.L42:
	testq	%r12, %r12
	je	.L48
	movl	$4, %ebx
	movq	88(%rsp), %r10
	movq	%r12, %rcx
	xorl	%r8d, %r8d
	movq	96(%rsp), %rbp
	movd	%ebx, %xmm5
	shrq	$2, %rcx
	movq	%r12, %rbx
	movq	%r10, %rdx
	leaq	-1(%r12), %r13
	xorl	%esi, %esi
	salq	$5, %rcx
	movdqa	.LC6(%rip), %xmm6
	movq	%rbp, %rax
	andq	$-4, %rbx
	leaq	0(,%r12,8), %r11
	pshufd	$0, %xmm5, %xmm5
	.p2align 4
	.p2align 3
.L49:
	cmpq	$2, %r13
	jbe	.L79
.L54:
	movd	%esi, %xmm7
	xorl	%edi, %edi
	movdqa	%xmm6, %xmm2
	pshufd	$0, %xmm7, %xmm3
	.p2align 4
	.p2align 3
.L52:
	movdqa	%xmm3, %xmm1
	movdqa	%xmm3, %xmm0
	paddd	%xmm2, %xmm1
	psubd	%xmm2, %xmm0
	cvtdq2pd	%xmm1, %xmm4
	pshufd	$238, %xmm1, %xmm1
	movups	%xmm4, (%rdx,%rdi)
	paddd	%xmm5, %xmm2
	cvtdq2pd	%xmm1, %xmm1
	movups	%xmm1, 16(%rdx,%rdi)
	cvtdq2pd	%xmm0, %xmm1
	pshufd	$238, %xmm0, %xmm0
	movups	%xmm1, (%rax,%rdi)
	cvtdq2pd	%xmm0, %xmm0
	movups	%xmm0, 16(%rax,%rdi)
	addq	$32, %rdi
	cmpq	%rdi, %rcx
	jne	.L52
	testb	$3, %r12b
	je	.L50
	movq	%rbx, %r9
	movl	%ebx, %edi
.L55:
	leal	(%rsi,%rdi), %r14d
	pxor	%xmm0, %xmm0
	addq	%r8, %r9
	cvtsi2sdl	%r14d, %xmm0
	movl	%esi, %r14d
	movsd	%xmm0, (%r10,%r9,8)
	pxor	%xmm0, %xmm0
	subl	%edi, %r14d
	cvtsi2sdl	%r14d, %xmm0
	movsd	%xmm0, 0(%rbp,%r9,8)
	leal	1(%rdi), %r9d
	movslq	%r9d, %r14
	cmpq	%r12, %r14
	jnb	.L51
	leal	(%rsi,%r9), %r15d
	pxor	%xmm0, %xmm0
	addq	%r8, %r14
	addl	$2, %edi
	cvtsi2sdl	%r15d, %xmm0
	movl	%esi, %r15d
	movsd	%xmm0, (%r10,%r14,8)
	pxor	%xmm0, %xmm0
	subl	%r9d, %r15d
	movslq	%edi, %r9
	cvtsi2sdl	%r15d, %xmm0
	movsd	%xmm0, 0(%rbp,%r14,8)
	cmpq	%r12, %r9
	jnb	.L51
	leal	(%rsi,%rdi), %r14d
	pxor	%xmm0, %xmm0
	addq	%r8, %r9
	cvtsi2sdl	%r14d, %xmm0
	movl	%esi, %r14d
	movsd	%xmm0, (%r10,%r9,8)
	pxor	%xmm0, %xmm0
	subl	%edi, %r14d
	cvtsi2sdl	%r14d, %xmm0
	movsd	%xmm0, 0(%rbp,%r9,8)
.L51:
	addl	$1, %esi
	addq	%r12, %r8
	addq	%r11, %rdx
	addq	%r11, %rax
	cmpl	%r12d, %esi
	jne	.L49
.L48:
	cmpq	$0, 56(%rsp)
	je	.L56
.L124:
	movl	%r12d, 76(%rsp)
	xorl	%r15d, %r15d
	xorl	%r13d, %r13d
	xorl	%r14d, %r14d
	movabsq	$9223372036854775807, %rax
	movq	$0x000000000, 16(%rsp)
	movq	$0x000000000, 24(%rsp)
	movq	$0, 32(%rsp)
	movq	%rax, (%rsp)
	movq	$0, 64(%rsp)
	.p2align 4
	.p2align 3
.L63:
	leaq	208(%rsp), %rsi
	movl	$4, %edi
	call	clock_gettime
	movl	76(%rsp), %ecx
	leaq	144(%rsp), %rdx
	leaq	112(%rsp), %rsi
	leaq	176(%rsp), %rdi
.LEHB2:
	call	_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i
.LEHE2:
	movq	192(%rsp), %rax
	movq	176(%rsp), %rbp
	movq	184(%rsp), %rbx
	movq	%rax, 40(%rsp)
	testq	%r14, %r14
	je	.L57
	movq	%r13, %rsi
	movq	%r14, %rdi
	subq	%r14, %rsi
	call	_ZdlPvm
.L57:
	leaq	224(%rsp), %rsi
	movl	$4, %edi
	call	clock_gettime
	movsd	24(%rsp), %xmm6
	pxor	%xmm7, %xmm7
	movq	224(%rsp), %rcx
	subq	208(%rsp), %rcx
	movq	32(%rsp), %rax
	pxor	%xmm2, %xmm2
	imulq	$1000000000, %rcx, %rcx
	addq	232(%rsp), %rcx
	subq	216(%rsp), %rcx
	cvtsi2sdq	%rcx, %xmm7
	movapd	%xmm7, %xmm1
	leaq	1(%rax), %r14
	movq	(%rsp), %rax
	subsd	%xmm6, %xmm1
	cvtsi2sdq	%r14, %xmm2
	addq	%rcx, 64(%rsp)
	movq	%rcx, %r13
	movsd	%xmm7, 48(%rsp)
	cmpq	%rcx, %rax
	cmovg	%rcx, %rax
	cmpq	%rcx, %r15
	movapd	%xmm1, %xmm0
	cmovl	%rcx, %r15
	movq	%rax, (%rsp)
	divsd	%xmm2, %xmm0
	addsd	%xmm6, %xmm0
	subsd	%xmm0, %xmm7
	movsd	%xmm0, 24(%rsp)
	movapd	%xmm7, %xmm0
	mulsd	%xmm1, %xmm0
	addsd	16(%rsp), %xmm0
	movsd	%xmm0, 16(%rsp)
	cmpq	%rbx, %rbp
	je	.L80
	subq	%rbp, %rbx
	movq	%rbp, %rax
	cmpq	$8, %rbx
	je	.L81
	subq	$8, %rbx
	pxor	%xmm0, %xmm0
	shrq	$3, %rbx
	leaq	1(%rbx), %rdx
	movq	%rdx, %rsi
	shrq	%rsi
	salq	$4, %rsi
	addq	%rbp, %rsi
	.p2align 5
	.p2align 4
	.p2align 3
.L60:
	addsd	(%rax), %xmm0
	addq	$16, %rax
	addsd	-8(%rax), %xmm0
	cmpq	%rsi, %rax
	jne	.L60
	movsd	%xmm0, 8(%rsp)
	testb	$1, %dl
	je	.L58
	andq	$-2, %rdx
	movapd	%xmm0, %xmm6
	leaq	0(%rbp,%rdx,8), %rax
.L59:
	addsd	(%rax), %xmm6
	movsd	%xmm6, 8(%rsp)
.L58:
	movl	$10, %edx
	movl	$.LC17, %esi
	movl	$_ZSt4cout, %edi
.LEHB3:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	_ZSt4cout(%rip), %rax
	movl	%r14d, %esi
	movl	$_ZSt4cout, %edi
	movq	-24(%rax), %rax
	movq	$3, _ZSt4cout+16(%rax)
	call	_ZNSolsEi
	movl	$2, %edx
	movl	$.LC18, %esi
	movq	%rax, %rdi
	movq	%rax, %rbx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	(%rbx), %rax
	movq	%r13, %rsi
	movq	%rbx, %rdi
	movq	-24(%rax), %rax
	movq	$12, 16(%rbx,%rax)
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$5, %edx
	movl	$.LC19, %esi
	movq	%rax, %rdi
	movq	%rax, %rbx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	(%rbx), %rax
	movq	%rbx, %rdi
	movsd	48(%rsp), %xmm0
	divsd	.LC20(%rip), %xmm0
	movq	-24(%rax), %rdx
	addq	%rbx, %rdx
	movl	24(%rdx), %eax
	movq	$6, 8(%rdx)
	andl	$-261, %eax
	orl	$4, %eax
	movl	%eax, 24(%rdx)
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC21, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	cmpq	%r14, 56(%rsp)
	je	.L123
	movq	%r14, 32(%rsp)
	movq	40(%rsp), %r13
	movq	%rbp, %r14
	jmp	.L63
	.p2align 4,,10
	.p2align 3
.L50:
	addl	$1, %esi
	addq	%r12, %r8
	addq	%r11, %rdx
	addq	%r11, %rax
	cmpl	%r12d, %esi
	jne	.L54
	cmpq	$0, 56(%rsp)
	jne	.L124
.L56:
	pxor	%xmm0, %xmm0
	xorl	%ebx, %ebx
	xorl	%r15d, %r15d
	xorl	%ebp, %ebp
	movq	$0x000000000, 8(%rsp)
	divsd	%xmm0, %xmm0
	movabsq	$9223372036854775807, %rax
	movq	$0, 40(%rsp)
	movq	%rax, (%rsp)
	movsd	%xmm0, 24(%rsp)
.L65:
	movq	$0x000000000, 16(%rsp)
	xorl	%r13d, %r13d
	jmp	.L70
	.p2align 4,,10
	.p2align 3
.L80:
	movq	$0x000000000, 8(%rsp)
	jmp	.L58
	.p2align 4,,10
	.p2align 3
.L123:
	movq	56(%rsp), %rax
	pxor	%xmm0, %xmm0
	pxor	%xmm1, %xmm1
	cvtsi2sdq	64(%rsp), %xmm1
	movq	40(%rsp), %rbx
	cvtsi2sdl	%eax, %xmm0
	divsd	%xmm0, %xmm1
	subq	%rbp, %rbx
	movsd	%xmm1, 24(%rsp)
	cmpq	$1, %rax
	je	.L65
	movsd	16(%rsp), %xmm5
	pxor	%xmm0, %xmm0
	cvtsi2sdq	32(%rsp), %xmm0
	divsd	%xmm0, %xmm5
	pxor	%xmm0, %xmm0
	ucomisd	%xmm5, %xmm0
	movsd	%xmm5, 16(%rsp)
	ja	.L118
	sqrtsd	%xmm5, %xmm5
	movq	%xmm5, %r13
.L70:
	movl	$1, %edx
	movl	$.LC12, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$9, %edx
	movl	$.LC22, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$34, %edx
	movl	$.LC0, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$1, %edx
	movl	$.LC12, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$33, %edx
	movl	$.LC9, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	_ZSt4cout(%rip), %rax
	movl	$.LC23, %esi
	movl	$_ZSt4cout, %edi
	movq	-24(%rax), %rdx
	movl	_ZSt4cout+24(%rdx), %eax
	movq	$6, _ZSt4cout+8(%rdx)
	andl	$-261, %eax
	orl	$4, %eax
	movl	%eax, _ZSt4cout+24(%rdx)
	movl	$9, %edx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movsd	24(%rsp), %xmm0
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$5, %edx
	movl	$.LC19, %esi
	movq	%rax, %rdi
	movq	%rax, %r14
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movsd	24(%rsp), %xmm6
	movq	%r14, %rdi
	divsd	.LC20(%rip), %xmm6
	movapd	%xmm6, %xmm0
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC21, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$9, %edx
	movl	$.LC24, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	(%rsp), %rsi
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$5, %edx
	movl	$.LC19, %esi
	movq	%rax, %rdi
	movq	%rax, %r14
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r14, %rdi
	pxor	%xmm0, %xmm0
	cvtsi2sdq	(%rsp), %xmm0
	divsd	.LC20(%rip), %xmm0
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC21, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$9, %edx
	movl	$.LC25, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r15, %rsi
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$5, %edx
	movl	$.LC19, %esi
	movq	%rax, %rdi
	movq	%rax, %r14
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	pxor	%xmm0, %xmm0
	movq	%r14, %rdi
	cvtsi2sdq	%r15, %xmm0
	divsd	.LC20(%rip), %xmm0
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC21, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$10, %edx
	movl	$.LC26, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movsd	16(%rsp), %xmm0
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$6, %edx
	movl	$.LC27, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$9, %edx
	movl	$.LC28, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r13, %xmm0
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$5, %edx
	movl	$.LC19, %esi
	movq	%rax, %rdi
	movq	%rax, %r14
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r13, %xmm5
	movq	%r14, %rdi
	divsd	.LC20(%rip), %xmm5
	movapd	%xmm5, %xmm0
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC21, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$11, %edx
	movl	$.LC29, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movsd	8(%rsp), %xmm0
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$1, %edx
	movl	$.LC12, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	104(%rsp), %r14
	movq	%r12, %rsi
	movq	%r14, %rdi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$1, %edx
	movl	$.LC30, %esi
	movq	%rax, %rdi
	movq	%rax, %r12
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	56(%rsp), %rsi
	movq	%r12, %rdi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$1, %edx
	movl	$.LC30, %esi
	movq	%rax, %rdi
	movq	%rax, %r12
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movsd	24(%rsp), %xmm0
	movq	%r12, %rdi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$1, %edx
	movl	$.LC30, %esi
	movq	%rax, %rdi
	movq	%rax, %r12
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	(%rsp), %rsi
	movq	%r12, %rdi
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$1, %edx
	movl	$.LC30, %esi
	movq	%rax, %rdi
	movq	%rax, %r12
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r15, %rsi
	movq	%r12, %rdi
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$1, %edx
	movl	$.LC30, %esi
	movq	%rax, %rdi
	movq	%rax, %r12
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movsd	16(%rsp), %xmm0
	movq	%r12, %rdi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$1, %edx
	movl	$.LC30, %esi
	movq	%rax, %rdi
	movq	%rax, %r12
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r13, %xmm0
	movq	%r12, %rdi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$1, %edx
	movl	$.LC12, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r14, %rdi
	call	_ZNSo5flushEv
.LEHE3:
	testq	%rbp, %rbp
	je	.L71
	movq	%rbx, %rsi
	movq	%rbp, %rdi
	call	_ZdlPvm
.L71:
	movq	96(%rsp), %rax
	testq	%rax, %rax
	je	.L72
	movq	80(%rsp), %rsi
	movq	%rax, %rdi
	call	_ZdlPvm
.L72:
	movq	88(%rsp), %rax
	testq	%rax, %rax
	je	.L39
	movq	80(%rsp), %rsi
	addq	$248, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	movq	%rax, %rdi
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
.LEHB4:
	jmp	_ZdlPvm
.LEHE4:
	.p2align 4,,10
	.p2align 3
.L79:
	.cfi_restore_state
	xorl	%edi, %edi
	xorl	%r9d, %r9d
	jmp	.L55
.L81:
	movq	$0x000000000, 8(%rsp)
	movsd	8(%rsp), %xmm6
	jmp	.L59
.L39:
	addq	$248, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
.L121:
	.cfi_restore_state
	movq	$0, 112(%rsp)
	movq	$0, 144(%rsp)
	movq	$0, 96(%rsp)
	movq	$0, 88(%rsp)
	jmp	.L42
.L122:
	movl	$8, %edi
.LEHB5:
	call	_Znwm
.LEHE5:
	movq	%rax, 96(%rsp)
	movl	$8, %ebp
	movq	%rax, 144(%rsp)
	movq	$0x000000000, (%rax)
	jmp	.L47
.L118:
	movsd	16(%rsp), %xmm0
	call	sqrt
	movq	%xmm0, %r13
	jmp	.L70
.L86:
	movq	%rax, %rbx
	jmp	.L45
.L85:
	movq	%rax, %rbx
	jmp	.L74
.L83:
	movq	%rax, %rbx
	jmp	.L75
.L84:
	movq	%rax, %rbx
	jmp	.L46
	.section	.gcc_except_table,"a",@progbits
.LLSDA3403:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE3403-.LLSDACSB3403
.LLSDACSB3403:
	.uleb128 .LEHB0-.LFB3403
	.uleb128 .LEHE0-.LEHB0
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB1-.LFB3403
	.uleb128 .LEHE1-.LEHB1
	.uleb128 .L84-.LFB3403
	.uleb128 0
	.uleb128 .LEHB2-.LFB3403
	.uleb128 .LEHE2-.LEHB2
	.uleb128 .L85-.LFB3403
	.uleb128 0
	.uleb128 .LEHB3-.LFB3403
	.uleb128 .LEHE3-.LEHB3
	.uleb128 .L83-.LFB3403
	.uleb128 0
	.uleb128 .LEHB4-.LFB3403
	.uleb128 .LEHE4-.LEHB4
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB5-.LFB3403
	.uleb128 .LEHE5-.LEHB5
	.uleb128 .L86-.LFB3403
	.uleb128 0
.LLSDACSE3403:
	.text
	.cfi_endproc
	.section	.text.unlikely
	.cfi_startproc
	.cfi_personality 0x3,__gxx_personality_v0
	.cfi_lsda 0x3,.LLSDAC3403
	.type	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE.cold, @function
_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE.cold:
.LFSB3403:
.L115:
	.cfi_def_cfa_offset 304
	.cfi_offset 3, -56
	.cfi_offset 6, -48
	.cfi_offset 12, -40
	.cfi_offset 13, -32
	.cfi_offset 14, -24
	.cfi_offset 15, -16
	movl	$.LC15, %edi
.LEHB6:
	call	_ZSt20__throw_length_errorPKc
.L45:
	movl	$8, %ebp
.L46:
	movq	88(%rsp), %rdi
	movq	%rbp, %rsi
	call	_ZdlPvm
.L78:
	movq	%rbx, %rdi
	call	_Unwind_Resume
.LEHE6:
.L74:
	movq	%r13, 40(%rsp)
	movq	%r14, %rbp
.L75:
	testq	%rbp, %rbp
	je	.L76
	movq	40(%rsp), %rsi
	movq	%rbp, %rdi
	subq	%rbp, %rsi
	call	_ZdlPvm
.L76:
	cmpq	$0, 96(%rsp)
	je	.L77
	movq	80(%rsp), %rsi
	movq	96(%rsp), %rdi
	call	_ZdlPvm
.L77:
	movq	80(%rsp), %rbp
	cmpq	$0, 88(%rsp)
	je	.L78
	jmp	.L46
	.cfi_endproc
.LFE3403:
	.section	.gcc_except_table
.LLSDAC3403:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSEC3403-.LLSDACSBC3403
.LLSDACSBC3403:
	.uleb128 .LEHB6-.LCOLDB31
	.uleb128 .LEHE6-.LEHB6
	.uleb128 0
	.uleb128 0
.LLSDACSEC3403:
	.section	.text.unlikely
	.text
	.size	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE, .-_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE
	.section	.text.unlikely
	.size	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE.cold, .-_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE.cold
.LCOLDE31:
	.text
.LHOTE31:
	.section	.rodata.str1.1
.LC32:
	.string	"matrix_benchmark.csv"
	.section	.rodata.str1.8
	.align 8
.LC33:
	.string	"basic_string: construction from null is not valid"
	.section	.rodata.str1.1
.LC34:
	.string	"Error: could not open "
.LC35:
	.string	"matrix_size,"
.LC36:
	.string	"iterations,"
.LC37:
	.string	"average_ns,"
.LC38:
	.string	"minimum_ns,"
.LC39:
	.string	"maximum_ns,"
.LC40:
	.string	"variance_ns2,"
.LC41:
	.string	"stddev_ns\n"
	.section	.rodata.str1.8
	.align 8
.LC46:
	.string	"\nBenchmark results written to "
	.section	.text.unlikely
.LCOLDB47:
	.section	.text.startup,"ax",@progbits
.LHOTB47:
	.p2align 4
	.globl	main
	.type	main, @function
main:
.LFB3421:
	.cfi_startproc
	.cfi_personality 0x3,__gxx_personality_v0
	.cfi_lsda 0x3,.LLSDA3421
	pushq	%r15
	.cfi_def_cfa_offset 16
	.cfi_offset 15, -16
	pushq	%r14
	.cfi_def_cfa_offset 24
	.cfi_offset 14, -24
	pushq	%r13
	.cfi_def_cfa_offset 32
	.cfi_offset 13, -32
	pushq	%r12
	.cfi_def_cfa_offset 40
	.cfi_offset 12, -40
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$680, %rsp
	.cfi_def_cfa_offset 736
	cmpl	$1, %edi
	jle	.L151
	movq	8(%rsi), %r12
	leaq	16(%rsp), %rbp
	movq	%rbp, (%rsp)
	testq	%r12, %r12
	je	.L147
	movq	%r12, %rdi
	call	strlen
	movq	%rax, 160(%rsp)
	movq	%rax, %rbx
	cmpq	$15, %rax
	ja	.L127
	cmpq	$1, %rax
	je	.L152
	movq	%rsp, %r15
	testq	%rax, %rax
	jne	.L153
.L132:
	movq	160(%rsp), %rax
	movq	(%rsp), %rdx
	movq	%rax, 8(%rsp)
	movb	$0, (%rdx,%rax)
.LEHB7:
	call	_Z23measure_timing_overheadv
	movl	$16, %edx
	movq	%r15, %rsi
	leaq	160(%rsp), %rdi
	call	_ZNSt14basic_ofstreamIcSt11char_traitsIcEEC1ERKNSt7__cxx1112basic_stringIcS1_SaIcEEESt13_Ios_Openmode
.LEHE7:
	leaq	272(%rsp), %rdi
	call	_ZNKSt12__basic_fileIcE7is_openEv
	testb	%al, %al
	je	.L154
	movl	$12, %edx
	movl	$.LC35, %esi
	leaq	160(%rsp), %rdi
.LEHB8:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$11, %edx
	movl	$.LC36, %esi
	leaq	160(%rsp), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$11, %edx
	movl	$.LC37, %esi
	leaq	160(%rsp), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$11, %edx
	movl	$.LC38, %esi
	leaq	160(%rsp), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$11, %edx
	movl	$.LC39, %esi
	leaq	160(%rsp), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$13, %edx
	movl	$.LC40, %esi
	leaq	160(%rsp), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$.LC41, %esi
	leaq	160(%rsp), %rdi
	call	_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
	leaq	40(%rsp), %rdi
	movl	$10, %ecx
	leaq	32(%rsp), %r13
	movq	160(%rsp), %rax
	leaq	160(%rsp), %rdx
	leaq	80(%rsp), %r14
	movdqa	.LC42(%rip), %xmm0
	movq	$512, 144(%rsp)
	addq	-24(%rax), %rdx
	leaq	152(%rsp), %r12
	movq	$100, 32(%rsp)
	movl	24(%rdx), %eax
	movaps	%xmm0, 80(%rsp)
	movdqa	.LC43(%rip), %xmm0
	movq	$3, 8(%rdx)
	andl	$-261, %eax
	movaps	%xmm0, 96(%rsp)
	movdqa	.LC44(%rip), %xmm0
	orl	$4, %eax
	movl	%eax, 24(%rdx)
	xorl	%eax, %eax
	rep stosl
	movaps	%xmm0, 112(%rsp)
	movdqa	.LC45(%rip), %xmm0
	movaps	%xmm0, 128(%rsp)
	.p2align 4
	.p2align 3
.L135:
	movq	0(%r13), %rbp
	movq	%r14, %rbx
	.p2align 4
	.p2align 3
.L136:
	movq	(%rbx), %rdi
	leaq	160(%rsp), %rdx
	movq	%rbp, %rsi
	call	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE
	addq	$8, %rbx
	cmpq	%rbx, %r12
	jne	.L136
	addq	$8, %r13
	cmpq	%r14, %r13
	jne	.L135
	leaq	160(%rsp), %rdi
	call	_ZNSt14basic_ofstreamIcSt11char_traitsIcEE5closeEv
	movl	$30, %edx
	movl	$.LC46, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	8(%rsp), %rdx
	movq	(%rsp), %rsi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$.LC12, %esi
	movq	%rax, %rdi
	call	_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
.LEHE8:
	xorl	%ebx, %ebx
.L134:
	leaq	160(%rsp), %rdi
	call	_ZNSt14basic_ofstreamIcSt11char_traitsIcEED1Ev
	movq	%r15, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	addq	$680, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 56
	movl	%ebx, %eax
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%rbp
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	ret
.L152:
	.cfi_restore_state
	movzbl	(%r12), %eax
	movq	%rsp, %r15
	movb	%al, 16(%rsp)
	jmp	.L132
.L151:
	leaq	16(%rsp), %rax
	movl	$20, %ebx
	movq	$20, 160(%rsp)
	movl	$.LC32, %r12d
	movq	%rax, (%rsp)
.L127:
	movq	%rsp, %rdi
	leaq	160(%rsp), %rsi
	xorl	%edx, %edx
	movq	%rsp, %r15
.LEHB9:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm
.LEHE9:
	movq	%rax, (%rsp)
	movq	%rax, %rdi
	movq	160(%rsp), %rax
	movq	%rax, 16(%rsp)
.L130:
	movq	%rbx, %rdx
	movq	%r12, %rsi
	call	memcpy
	jmp	.L132
.L154:
	movl	$22, %edx
	movl	$.LC34, %esi
	movl	$_ZSt4cerr, %edi
.LEHB10:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	8(%rsp), %rdx
	movq	(%rsp), %rsi
	movl	$_ZSt4cerr, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$.LC12, %esi
	movq	%rax, %rdi
	call	_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
.LEHE10:
	movl	$1, %ebx
	jmp	.L134
.L153:
	movq	%rbp, %rdi
	jmp	.L130
.L141:
	movq	%rax, %rbx
	jmp	.L139
.L142:
	movq	%rax, %rbx
	jmp	.L138
	.section	.gcc_except_table
.LLSDA3421:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE3421-.LLSDACSB3421
.LLSDACSB3421:
	.uleb128 .LEHB7-.LFB3421
	.uleb128 .LEHE7-.LEHB7
	.uleb128 .L141-.LFB3421
	.uleb128 0
	.uleb128 .LEHB8-.LFB3421
	.uleb128 .LEHE8-.LEHB8
	.uleb128 .L142-.LFB3421
	.uleb128 0
	.uleb128 .LEHB9-.LFB3421
	.uleb128 .LEHE9-.LEHB9
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB10-.LFB3421
	.uleb128 .LEHE10-.LEHB10
	.uleb128 .L142-.LFB3421
	.uleb128 0
.LLSDACSE3421:
	.section	.text.startup
	.cfi_endproc
	.section	.text.unlikely
	.cfi_startproc
	.cfi_personality 0x3,__gxx_personality_v0
	.cfi_lsda 0x3,.LLSDAC3421
	.type	main.cold, @function
main.cold:
.LFSB3421:
.L147:
	.cfi_def_cfa_offset 736
	.cfi_offset 3, -56
	.cfi_offset 6, -48
	.cfi_offset 12, -40
	.cfi_offset 13, -32
	.cfi_offset 14, -24
	.cfi_offset 15, -16
	movl	$.LC33, %edi
.LEHB11:
	call	_ZSt19__throw_logic_errorPKc
.L138:
	leaq	160(%rsp), %rdi
	call	_ZNSt14basic_ofstreamIcSt11char_traitsIcEED1Ev
.L139:
	movq	%r15, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movq	%rbx, %rdi
	call	_Unwind_Resume
.LEHE11:
	.cfi_endproc
.LFE3421:
	.section	.gcc_except_table
.LLSDAC3421:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSEC3421-.LLSDACSBC3421
.LLSDACSBC3421:
	.uleb128 .LEHB11-.LCOLDB47
	.uleb128 .LEHE11-.LEHB11
	.uleb128 0
	.uleb128 0
.LLSDACSEC3421:
	.section	.text.unlikely
	.section	.text.startup
	.size	main, .-main
	.section	.text.unlikely
	.size	main.cold, .-main.cold
.LCOLDE47:
	.section	.text.startup
.LHOTE47:
	.section	.rodata.cst16,"aM",@progbits,16
	.align 16
.LC6:
	.long	0
	.long	1
	.long	2
	.long	3
	.section	.rodata.cst8,"aM",@progbits,8
	.align 8
.LC20:
	.long	0
	.long	1104006501
	.section	.rodata.cst16
	.align 16
.LC42:
	.quad	2
	.quad	4
	.align 16
.LC43:
	.quad	8
	.quad	16
	.align 16
.LC44:
	.quad	32
	.quad	64
	.align 16
.LC45:
	.quad	128
	.quad	256
	.globl	__gxx_personality_v0
	.ident	"GCC: (GNU) 15.2.1 20251117"
	.section	.note.GNU-stack,"",@progbits
