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
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC0:
	.string	"PAPI_get_real_nsec()"
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
	.section	.rodata.str1.1
.LC1:
	.string	"PAPI_library_init failed: "
.LC2:
	.string	"\n"
	.text
	.p2align 4
	.globl	_Z15initialize_papiv
	.type	_Z15initialize_papiv, @function
_Z15initialize_papiv:
.LFB3388:
	.cfi_startproc
	subq	$24, %rsp
	.cfi_def_cfa_offset 32
	movl	$117571584, %edi
	call	PAPI_library_init
	movl	%eax, %ecx
	movl	$1, %eax
	cmpl	$117571584, %ecx
	jne	.L12
	addq	$24, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L12:
	.cfi_restore_state
	movl	$_ZSt4cerr, %edi
	movl	$26, %edx
	movl	$.LC1, %esi
	movl	%ecx, 8(%rsp)
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	8(%rsp), %edi
	call	PAPI_strerror
	testq	%rax, %rax
	je	.L13
	movq	%rax, %rdi
	movq	%rax, 8(%rsp)
	call	strlen
	movq	8(%rsp), %rsi
	movl	$_ZSt4cerr, %edi
	movq	%rax, %rdx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
.L7:
	movl	$1, %edx
	movl	$.LC2, %esi
	movl	$_ZSt4cerr, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	xorl	%eax, %eax
	addq	$24, %rsp
	.cfi_remember_state
	.cfi_def_cfa_offset 8
	ret
	.p2align 4,,10
	.p2align 3
.L13:
	.cfi_restore_state
	movq	_ZSt4cerr(%rip), %rax
	movq	-24(%rax), %rdi
	addq	$_ZSt4cerr, %rdi
	movl	32(%rdi), %esi
	orl	$1, %esi
	call	_ZNSt9basic_iosIcSt11char_traitsIcEE5clearESt12_Ios_Iostate
	jmp	.L7
	.cfi_endproc
.LFE3388:
	.size	_Z15initialize_papiv, .-_Z15initialize_papiv
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align 8
.LC3:
	.string	"Measuring PAPI_get_real_nsec() overhead..."
	.section	.rodata.str1.1
.LC4:
	.string	"Iterations: %d\n"
.LC5:
	.string	"Average latency: %lld ns\n"
.LC6:
	.string	"Minimum latency: %lld ns\n"
.LC7:
	.string	"Maximum latency: %lld ns\n"
	.text
	.p2align 4
	.globl	_Z23measure_timing_overheadv
	.type	_Z23measure_timing_overheadv, @function
_Z23measure_timing_overheadv:
.LFB3389:
	.cfi_startproc
	pushq	%r14
	.cfi_def_cfa_offset 16
	.cfi_offset 14, -16
	movl	$.LC3, %edi
	movq	$-1, %r14
	pushq	%r13
	.cfi_def_cfa_offset 24
	.cfi_offset 13, -24
	pushq	%r12
	.cfi_def_cfa_offset 32
	.cfi_offset 12, -32
	xorl	%r12d, %r12d
	pushq	%rbp
	.cfi_def_cfa_offset 40
	.cfi_offset 6, -40
	movl	$100000, %ebp
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset 3, -48
	xorl	%ebx, %ebx
	call	puts
	jmp	.L16
	.p2align 4,,10
	.p2align 3
.L15:
	cmpq	%rax, %rbx
	cmovl	%rax, %rbx
	subl	$1, %ebp
	je	.L20
.L16:
	call	PAPI_get_real_nsec
	movq	%rax, %r13
	call	PAPI_get_real_nsec
	subq	%r13, %rax
	addq	%rax, %r12
	cmpq	$-1, %r14
	je	.L17
	cmpq	%r14, %rax
	jge	.L15
.L17:
	cmpq	%rax, %rbx
	movq	%rax, %r14
	cmovl	%rax, %rbx
	subl	$1, %ebp
	jne	.L16
.L20:
	movl	$100000, %esi
	movl	$.LC4, %edi
	xorl	%eax, %eax
	call	printf
	movl	$.LC5, %edi
	movabsq	$3022314549036572937, %rax
	imulq	%r12
	sarq	$63, %r12
	xorl	%eax, %eax
	sarq	$14, %rdx
	subq	%r12, %rdx
	movq	%rdx, %rsi
	call	printf
	movq	%r14, %rsi
	movl	$.LC6, %edi
	xorl	%eax, %eax
	call	printf
	movq	%rbx, %rsi
	movl	$.LC7, %edi
	xorl	%eax, %eax
	call	printf
	popq	%rbx
	.cfi_def_cfa_offset 40
	xorl	%eax, %eax
	popq	%rbp
	.cfi_def_cfa_offset 32
	popq	%r12
	.cfi_def_cfa_offset 24
	popq	%r13
	.cfi_def_cfa_offset 16
	popq	%r14
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE3389:
	.size	_Z23measure_timing_overheadv, .-_Z23measure_timing_overheadv
	.p2align 4
	.globl	_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i
	.type	_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i, @function
_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i:
.LFB3390:
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
	je	.L22
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
.L33:
	movq	%rcx, 8(%r12)
	testl	%ebx, %ebx
	jle	.L21
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
.L24:
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
.L32:
	movsd	(%rdi), %xmm2
	cmpl	$1, %ebx
	je	.L25
	cmpq	%rdx, %r8
	je	.L25
.L48:
	movapd	%xmm2, %xmm1
	xorl	%ecx, %ecx
	unpcklpd	%xmm1, %xmm1
	.p2align 5
	.p2align 4
	.p2align 3
.L26:
	movupd	(%rax,%rcx), %xmm0
	movupd	(%rdx,%rcx), %xmm3
	mulpd	%xmm1, %xmm0
	addpd	%xmm3, %xmm0
	movups	%xmm0, (%rdx,%rcx)
	addq	$16, %rcx
	cmpq	%rsi, %rcx
	jne	.L26
	testb	$1, %bl
	je	.L27
	leal	(%r14,%r9), %ecx
	movslq	%ecx, %rcx
	mulsd	0(%r13,%rcx,8), %xmm2
	addsd	(%r15), %xmm2
	movsd	%xmm2, (%r15)
.L27:
	addq	$8, %rdi
	cmpq	%rbp, %rdi
	je	.L45
	addq	%r10, %r8
	movsd	(%rdi), %xmm2
	addq	%r10, %rax
	addl	%ebx, %r9d
	cmpq	%rdx, %r8
	jne	.L48
.L25:
	leaq	(%rax,%r10), %r12
	movq	%rdx, %rcx
	.p2align 5
	.p2align 4
	.p2align 3
.L28:
	movsd	(%rax), %xmm0
	addq	$8, %rax
	addq	$8, %rcx
	mulsd	%xmm2, %xmm0
	addsd	-8(%rcx), %xmm0
	movsd	%xmm0, -8(%rcx)
	cmpq	%r12, %rax
	jne	.L28
	addq	$8, %rdi
	addl	%ebx, %r9d
	addq	%r10, %r8
	cmpq	%rbp, %rdi
	jne	.L32
	.p2align 4
	.p2align 3
.L45:
	movl	(%rsp), %ecx
	addq	%r10, %rbp
	addq	%r10, %rdx
	addl	%ebx, %r11d
	addl	$1, %ecx
	cmpl	%ecx, %ebx
	jne	.L24
	movq	24(%rsp), %r12
.L21:
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
.L22:
	.cfi_restore_state
	movq	$0, (%rdi)
	xorl	%r15d, %r15d
	xorl	%ecx, %ecx
	movq	$0, 16(%rdi)
	jmp	.L33
	.cfi_endproc
.LFE3390:
	.size	_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i, .-_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i
	.section	.rodata.str1.8
	.align 8
.LC10:
	.string	"\nMatrix multiplication benchmark\n"
	.align 8
.LC11:
	.string	"--------------------------------\n"
	.section	.rodata.str1.1
.LC12:
	.string	"Matrix size: "
.LC13:
	.string	" x "
.LC14:
	.string	"Iterations:  "
.LC15:
	.string	"Timer:       "
	.section	.rodata.str1.8
	.align 8
.LC16:
	.string	"cannot create std::vector larger than max_size()"
	.section	.rodata.str1.1
.LC18:
	.string	"Iteration "
.LC19:
	.string	": "
.LC20:
	.string	" ns ("
.LC22:
	.string	" s)\n"
.LC23:
	.string	"Results: "
.LC24:
	.string	"Average: "
.LC25:
	.string	"Minimum: "
.LC26:
	.string	"Maximum: "
.LC27:
	.string	"Variance: "
.LC28:
	.string	" ns^2\n"
.LC29:
	.string	"Std dev: "
.LC30:
	.string	"\nChecksum: "
.LC31:
	.string	","
	.section	.text.unlikely,"ax",@progbits
.LCOLDB32:
	.text
.LHOTB32:
	.p2align 4
	.globl	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE
	.type	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE, @function
_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE:
.LFB3404:
	.cfi_startproc
	.cfi_personality 0x3,__gxx_personality_v0
	.cfi_lsda 0x3,.LLSDA3404
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
	pushq	%rbp
	.cfi_def_cfa_offset 48
	.cfi_offset 6, -48
	movq	%rdi, %rbp
	movl	$_ZSt4cout, %edi
	pushq	%rbx
	.cfi_def_cfa_offset 56
	.cfi_offset 3, -56
	subq	$200, %rsp
	.cfi_def_cfa_offset 256
	movq	%rsi, 48(%rsp)
	movl	$.LC10, %esi
	movq	%rdx, 88(%rsp)
	movl	$33, %edx
.LEHB0:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$33, %edx
	movl	$.LC11, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$13, %edx
	movl	$.LC12, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%rbp, %rsi
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$3, %edx
	movl	$.LC13, %esi
	movq	%rax, %rbx
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%rbp, %rsi
	movq	%rbx, %rdi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$1, %edx
	movl	$.LC2, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$13, %edx
	movl	$.LC14, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r15, %rsi
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$1, %edx
	movl	$.LC2, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$13, %edx
	movl	$.LC15, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$20, %edx
	movl	$.LC0, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$1, %edx
	movl	$.LC2, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$1, %edx
	movl	$.LC2, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%rbp, %rax
	imulq	%rbp, %rax
	movq	%rax, 64(%rsp)
	shrq	$60, %rax
	jne	.L143
	cmpq	$0, 64(%rsp)
	je	.L153
	movq	64(%rsp), %r15
	leaq	0(,%r15,8), %rbx
	movq	%rbx, %rdi
	call	_Znwm
.LEHE0:
	movq	%rax, 72(%rsp)
	movq	%rax, 96(%rsp)
	movq	$0x000000000, (%rax)
	cmpq	$1, %r15
	je	.L154
	leaq	8(%rax), %rdi
	leaq	-8(%rbx), %rdx
	xorl	%esi, %esi
	call	memset
	movq	%rbx, %rdi
.LEHB1:
	call	_Znwm
.LEHE1:
	leaq	8(%rax), %rdi
	leaq	-8(%rbx), %rdx
	xorl	%esi, %esi
	movq	%rax, 80(%rsp)
	movq	$0x000000000, (%rax)
	movq	%rax, 128(%rsp)
	call	memset
.L57:
	movq	%rbx, 64(%rsp)
.L52:
	testq	%rbp, %rbp
	je	.L58
	movl	$4, %ebx
	movq	72(%rsp), %r12
	movq	%rbp, %rcx
	xorl	%r8d, %r8d
	movq	80(%rsp), %r10
	movd	%ebx, %xmm5
	shrq	$2, %rcx
	movq	%rbp, %rbx
	movq	%r12, %rdx
	leaq	-1(%rbp), %r13
	xorl	%esi, %esi
	salq	$5, %rcx
	movdqa	.LC8(%rip), %xmm6
	movq	%r10, %rax
	andq	$-4, %rbx
	leaq	0(,%rbp,8), %r11
	pshufd	$0, %xmm5, %xmm5
	.p2align 4
	.p2align 3
.L59:
	cmpq	$2, %r13
	jbe	.L99
.L64:
	movd	%esi, %xmm7
	xorl	%edi, %edi
	movdqa	%xmm6, %xmm2
	pshufd	$0, %xmm7, %xmm3
	.p2align 4
	.p2align 3
.L62:
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
	jne	.L62
	testb	$3, %bpl
	je	.L60
	movq	%rbx, %r9
	movl	%ebx, %edi
.L65:
	leal	(%rsi,%rdi), %r14d
	pxor	%xmm0, %xmm0
	addq	%r8, %r9
	cvtsi2sdl	%r14d, %xmm0
	movl	%esi, %r14d
	movsd	%xmm0, (%r12,%r9,8)
	pxor	%xmm0, %xmm0
	subl	%edi, %r14d
	cvtsi2sdl	%r14d, %xmm0
	movsd	%xmm0, (%r10,%r9,8)
	leal	1(%rdi), %r9d
	movslq	%r9d, %r14
	cmpq	%rbp, %r14
	jnb	.L61
	leal	(%r9,%rsi), %r15d
	pxor	%xmm0, %xmm0
	addq	%r8, %r14
	addl	$2, %edi
	cvtsi2sdl	%r15d, %xmm0
	movl	%esi, %r15d
	movsd	%xmm0, (%r12,%r14,8)
	pxor	%xmm0, %xmm0
	subl	%r9d, %r15d
	movslq	%edi, %r9
	cvtsi2sdl	%r15d, %xmm0
	movsd	%xmm0, (%r10,%r14,8)
	cmpq	%rbp, %r9
	jnb	.L61
	leal	(%rdi,%rsi), %r14d
	pxor	%xmm0, %xmm0
	addq	%r8, %r9
	cvtsi2sdl	%r14d, %xmm0
	movl	%esi, %r14d
	movsd	%xmm0, (%r12,%r9,8)
	pxor	%xmm0, %xmm0
	subl	%edi, %r14d
	cvtsi2sdl	%r14d, %xmm0
	movsd	%xmm0, (%r10,%r9,8)
.L61:
	addl	$1, %esi
	addq	%rbp, %r8
	addq	%r11, %rdx
	addq	%r11, %rax
	cmpl	%esi, %ebp
	jne	.L59
.L58:
	movabsq	$9223372036854775807, %rax
	xorl	%r13d, %r13d
	xorl	%r14d, %r14d
	xorl	%ebx, %ebx
	movq	$0x000000000, 16(%rsp)
	movq	$0x000000000, 24(%rsp)
	movq	$0, 8(%rsp)
	movq	%rax, (%rsp)
	movq	$0, 56(%rsp)
	movq	$0, 40(%rsp)
	cmpq	%r13, 48(%rsp)
	je	.L155
	.p2align 4
	.p2align 3
.L87:
.LEHB2:
	call	PAPI_get_real_nsec
	leaq	160(%rsp), %rdi
	leaq	128(%rsp), %rdx
	movl	%ebp, %ecx
	movq	%rax, %r15
	leaq	96(%rsp), %rsi
	call	_Z17multiply_matricesRKSt6vectorIdSaIdEES3_i
.LEHE2:
	movq	176(%rsp), %rax
	movq	160(%rsp), %r12
	movq	168(%rsp), %rbx
	movq	%rax, 32(%rsp)
	testq	%r14, %r14
	je	.L67
	movq	40(%rsp), %rsi
	movq	%r14, %rdi
	subq	%r14, %rsi
	call	_ZdlPvm
.L67:
.LEHB3:
	call	PAPI_get_real_nsec
.LEHE3:
	subq	%r15, %rax
	pxor	%xmm7, %xmm7
	addq	$1, %r13
	addq	%rax, 56(%rsp)
	movsd	24(%rsp), %xmm6
	cvtsi2sdq	%rax, %xmm7
	movapd	%xmm7, %xmm1
	pxor	%xmm2, %xmm2
	cvtsi2sdq	%r13, %xmm2
	movq	%rax, %r14
	movq	(%rsp), %rax
	movsd	%xmm7, 40(%rsp)
	subsd	%xmm6, %xmm1
	cmpq	%r14, %rax
	cmovg	%r14, %rax
	movapd	%xmm1, %xmm0
	divsd	%xmm2, %xmm0
	movq	%rax, (%rsp)
	movq	8(%rsp), %rax
	cmpq	%r14, %rax
	cmovl	%r14, %rax
	movq	%rax, 8(%rsp)
	addsd	%xmm6, %xmm0
	subsd	%xmm0, %xmm7
	movsd	%xmm0, 24(%rsp)
	movapd	%xmm7, %xmm0
	mulsd	%xmm1, %xmm0
	addsd	16(%rsp), %xmm0
	movsd	%xmm0, 16(%rsp)
	cmpq	%rbx, %r12
	je	.L156
	subq	%r12, %rbx
	movq	%r12, %rax
	cmpq	$8, %rbx
	je	.L101
	subq	$8, %rbx
	pxor	%xmm0, %xmm0
	shrq	$3, %rbx
	leaq	1(%rbx), %rdx
	movq	%rdx, %rsi
	shrq	%rsi
	salq	$4, %rsi
	addq	%r12, %rsi
	.p2align 5
	.p2align 4
	.p2align 3
.L73:
	addsd	(%rax), %xmm0
	addq	$16, %rax
	addsd	-8(%rax), %xmm0
	cmpq	%rsi, %rax
	jne	.L73
	movq	%xmm0, %rbx
	testb	$1, %dl
	je	.L71
	andq	$-2, %rdx
	leaq	(%r12,%rdx,8), %rax
.L72:
	movq	%rbx, %xmm6
	addsd	(%rax), %xmm6
	movq	%xmm6, %rbx
.L71:
	movl	$10, %edx
	movl	$.LC18, %esi
	movl	$_ZSt4cout, %edi
.LEHB4:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
.LEHE4:
	movq	_ZSt4cout(%rip), %rax
	movl	%r13d, %esi
	movl	$_ZSt4cout, %edi
	movq	-24(%rax), %rax
	movq	$3, _ZSt4cout+16(%rax)
.LEHB5:
	call	_ZNSolsEi
.LEHE5:
	movl	$2, %edx
	movl	$.LC19, %esi
	movq	%rax, %rdi
	movq	%rax, %r15
.LEHB6:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
.LEHE6:
	movq	(%r15), %rax
	movq	%r14, %rsi
	movq	%r15, %rdi
	movq	-24(%rax), %rax
	movq	$12, 16(%r15,%rax)
.LEHB7:
	call	_ZNSo9_M_insertIxEERSoT_
.LEHE7:
	movl	$5, %edx
	movl	$.LC20, %esi
	movq	%rax, %rdi
	movq	%rax, %r15
.LEHB8:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
.LEHE8:
	movq	(%r15), %rax
	movq	%r15, %rdi
	movsd	40(%rsp), %xmm0
	divsd	.LC21(%rip), %xmm0
	movq	-24(%rax), %rdx
	addq	%r15, %rdx
	movl	24(%rdx), %eax
	movq	$6, 8(%rdx)
	andl	$-261, %eax
	orl	$4, %eax
	movl	%eax, 24(%rdx)
.LEHB9:
	call	_ZNSo9_M_insertIdEERSoT_
.LEHE9:
	movl	$4, %edx
	movl	$.LC22, %esi
	movq	%rax, %rdi
.LEHB10:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
.LEHE10:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
	cmpq	%r13, 48(%rsp)
	jne	.L87
.L155:
	movq	48(%rsp), %rax
	pxor	%xmm0, %xmm0
	pxor	%xmm1, %xmm1
	cvtsi2sdq	56(%rsp), %xmm1
	cvtsi2sdl	%eax, %xmm0
	divsd	%xmm0, %xmm1
	movq	%xmm1, %r12
	cmpq	$1, %rax
	jle	.L103
	movsd	16(%rsp), %xmm5
	subq	$1, %rax
	pxor	%xmm0, %xmm0
	cvtsi2sdq	%rax, %xmm0
	divsd	%xmm0, %xmm5
	pxor	%xmm0, %xmm0
	ucomisd	%xmm5, %xmm0
	movsd	%xmm5, 16(%rsp)
	ja	.L150
	sqrtsd	%xmm5, %xmm5
	movq	%xmm5, %r13
.L91:
	movl	$1, %edx
	movl	$.LC2, %esi
	movl	$_ZSt4cout, %edi
.LEHB11:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$9, %edx
	movl	$.LC23, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$20, %edx
	movl	$.LC0, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$1, %edx
	movl	$.LC2, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$33, %edx
	movl	$.LC11, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	_ZSt4cout(%rip), %rax
	movl	$.LC24, %esi
	movl	$_ZSt4cout, %edi
	movq	-24(%rax), %rdx
	movl	_ZSt4cout+24(%rdx), %eax
	movq	$6, _ZSt4cout+8(%rdx)
	andl	$-261, %eax
	orl	$4, %eax
	movl	%eax, _ZSt4cout+24(%rdx)
	movl	$9, %edx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r12, %xmm0
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$5, %edx
	movl	$.LC20, %esi
	movq	%rax, %rdi
	movq	%rax, %r15
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r15, %rdi
	movq	%r12, %xmm0
	divsd	.LC21(%rip), %xmm0
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC22, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$9, %edx
	movl	$.LC25, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	(%rsp), %rsi
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$5, %edx
	movl	$.LC20, %esi
	movq	%rax, %rdi
	movq	%rax, %r15
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r15, %rdi
	pxor	%xmm0, %xmm0
	cvtsi2sdq	(%rsp), %xmm0
	divsd	.LC21(%rip), %xmm0
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC22, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$9, %edx
	movl	$.LC26, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	8(%rsp), %rsi
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$5, %edx
	movl	$.LC20, %esi
	movq	%rax, %rdi
	movq	%rax, %r15
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r15, %rdi
	pxor	%xmm0, %xmm0
	cvtsi2sdq	8(%rsp), %xmm0
	divsd	.LC21(%rip), %xmm0
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC22, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$10, %edx
	movl	$.LC27, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movsd	16(%rsp), %xmm0
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$6, %edx
	movl	$.LC28, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$9, %edx
	movl	$.LC29, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r13, %xmm0
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$5, %edx
	movl	$.LC20, %esi
	movq	%rax, %rdi
	movq	%rax, %r15
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r13, %xmm6
	movq	%r15, %rdi
	divsd	.LC21(%rip), %xmm6
	movapd	%xmm6, %xmm0
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$4, %edx
	movl	$.LC22, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$11, %edx
	movl	$.LC30, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%rbx, %xmm0
	movl	$_ZSt4cout, %edi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$1, %edx
	movl	$.LC2, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	88(%rsp), %r15
	movq	%rbp, %rsi
	movq	%r15, %rdi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$1, %edx
	movl	$.LC31, %esi
	movq	%rax, %rdi
	movq	%rax, %rbx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	48(%rsp), %rsi
	movq	%rbx, %rdi
	call	_ZNSo9_M_insertImEERSoT_
	movl	$1, %edx
	movl	$.LC31, %esi
	movq	%rax, %rdi
	movq	%rax, %rbx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r12, %xmm0
	movq	%rbx, %rdi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$1, %edx
	movl	$.LC31, %esi
	movq	%rax, %rdi
	movq	%rax, %rbx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	(%rsp), %rsi
	movq	%rbx, %rdi
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$1, %edx
	movl	$.LC31, %esi
	movq	%rax, %rdi
	movq	%rax, %rbx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	8(%rsp), %rsi
	movq	%rbx, %rdi
	call	_ZNSo9_M_insertIxEERSoT_
	movl	$1, %edx
	movl	$.LC31, %esi
	movq	%rax, %rdi
	movq	%rax, %rbx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movsd	16(%rsp), %xmm0
	movq	%rbx, %rdi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$1, %edx
	movl	$.LC31, %esi
	movq	%rax, %rdi
	movq	%rax, %rbx
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r13, %xmm0
	movq	%rbx, %rdi
	call	_ZNSo9_M_insertIdEERSoT_
	movl	$1, %edx
	movl	$.LC2, %esi
	movq	%rax, %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	%r15, %rdi
	call	_ZNSo5flushEv
.LEHE11:
	testq	%r14, %r14
	je	.L92
	movq	40(%rsp), %rsi
	movq	%r14, %rdi
	subq	%r14, %rsi
	call	_ZdlPvm
.L92:
	movq	80(%rsp), %rax
	testq	%rax, %rax
	je	.L93
	movq	64(%rsp), %rsi
	movq	%rax, %rdi
	call	_ZdlPvm
.L93:
	movq	72(%rsp), %rax
	testq	%rax, %rax
	je	.L49
	movq	64(%rsp), %rsi
	addq	$200, %rsp
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
.LEHB12:
	jmp	_ZdlPvm
.LEHE12:
	.p2align 4,,10
	.p2align 3
.L60:
	.cfi_restore_state
	addl	$1, %esi
	addq	%rbp, %r8
	addq	%r11, %rdx
	addq	%r11, %rax
	cmpl	%esi, %ebp
	jne	.L64
	jmp	.L58
	.p2align 4,,10
	.p2align 3
.L156:
	xorl	%ebx, %ebx
	jmp	.L71
	.p2align 4,,10
	.p2align 3
.L99:
	xorl	%edi, %edi
	xorl	%r9d, %r9d
	jmp	.L65
.L101:
	xorl	%ebx, %ebx
	jmp	.L72
.L49:
	addq	$200, %rsp
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
.L153:
	.cfi_restore_state
	movq	$0, 96(%rsp)
	movq	$0, 128(%rsp)
	movq	$0, 80(%rsp)
	movq	$0, 72(%rsp)
	jmp	.L52
.L103:
	movq	$0x000000000, 16(%rsp)
	xorl	%r13d, %r13d
	jmp	.L91
.L154:
	movl	$8, %edi
.LEHB13:
	call	_Znwm
.LEHE13:
	movq	%rax, 80(%rsp)
	movl	$8, %ebx
	movq	%rax, 128(%rsp)
	movq	$0x000000000, (%rax)
	jmp	.L57
.L150:
	movsd	16(%rsp), %xmm0
	call	sqrt
	movq	%xmm0, %r13
	jmp	.L91
.L114:
	movq	%rax, %rbp
	jmp	.L55
.L111:
	movq	%rax, %rbp
	jmp	.L69
.L112:
	movq	%rax, %rbp
	jmp	.L77
.L106:
	movq	%rax, %rbp
	jmp	.L95
.L113:
	movq	%rax, %rbp
	jmp	.L79
.L110:
	movq	%rax, %rbp
	jmp	.L81
.L107:
	movq	%rax, %rbp
	jmp	.L83
.L108:
	movq	%rax, %rbp
	jmp	.L85
.L109:
	movq	%rax, %rbp
	jmp	.L86
.L105:
	movq	%rax, %rbp
	jmp	.L56
.L104:
	movq	%rax, %rbp
	jmp	.L70
	.section	.gcc_except_table,"a",@progbits
.LLSDA3404:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE3404-.LLSDACSB3404
.LLSDACSB3404:
	.uleb128 .LEHB0-.LFB3404
	.uleb128 .LEHE0-.LEHB0
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB1-.LFB3404
	.uleb128 .LEHE1-.LEHB1
	.uleb128 .L105-.LFB3404
	.uleb128 0
	.uleb128 .LEHB2-.LFB3404
	.uleb128 .LEHE2-.LEHB2
	.uleb128 .L104-.LFB3404
	.uleb128 0
	.uleb128 .LEHB3-.LFB3404
	.uleb128 .LEHE3-.LEHB3
	.uleb128 .L111-.LFB3404
	.uleb128 0
	.uleb128 .LEHB4-.LFB3404
	.uleb128 .LEHE4-.LEHB4
	.uleb128 .L112-.LFB3404
	.uleb128 0
	.uleb128 .LEHB5-.LFB3404
	.uleb128 .LEHE5-.LEHB5
	.uleb128 .L106-.LFB3404
	.uleb128 0
	.uleb128 .LEHB6-.LFB3404
	.uleb128 .LEHE6-.LEHB6
	.uleb128 .L113-.LFB3404
	.uleb128 0
	.uleb128 .LEHB7-.LFB3404
	.uleb128 .LEHE7-.LEHB7
	.uleb128 .L110-.LFB3404
	.uleb128 0
	.uleb128 .LEHB8-.LFB3404
	.uleb128 .LEHE8-.LEHB8
	.uleb128 .L107-.LFB3404
	.uleb128 0
	.uleb128 .LEHB9-.LFB3404
	.uleb128 .LEHE9-.LEHB9
	.uleb128 .L108-.LFB3404
	.uleb128 0
	.uleb128 .LEHB10-.LFB3404
	.uleb128 .LEHE10-.LEHB10
	.uleb128 .L109-.LFB3404
	.uleb128 0
	.uleb128 .LEHB11-.LFB3404
	.uleb128 .LEHE11-.LEHB11
	.uleb128 .L104-.LFB3404
	.uleb128 0
	.uleb128 .LEHB12-.LFB3404
	.uleb128 .LEHE12-.LEHB12
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB13-.LFB3404
	.uleb128 .LEHE13-.LEHB13
	.uleb128 .L114-.LFB3404
	.uleb128 0
.LLSDACSE3404:
	.text
	.cfi_endproc
	.section	.text.unlikely
	.cfi_startproc
	.cfi_personality 0x3,__gxx_personality_v0
	.cfi_lsda 0x3,.LLSDAC3404
	.type	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE.cold, @function
_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE.cold:
.LFSB3404:
.L55:
	.cfi_def_cfa_offset 256
	.cfi_offset 3, -56
	.cfi_offset 6, -48
	.cfi_offset 12, -40
	.cfi_offset 13, -32
	.cfi_offset 14, -24
	.cfi_offset 15, -16
	movl	$8, %ebx
.L56:
	movq	72(%rsp), %rdi
	movq	%rbx, %rsi
	call	_ZdlPvm
.L98:
	movq	%rbp, %rdi
.LEHB14:
	call	_Unwind_Resume
.L69:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
.L70:
	testq	%r14, %r14
	je	.L96
	movq	40(%rsp), %rsi
	movq	%r14, %rdi
	subq	%r14, %rsi
	call	_ZdlPvm
.L96:
	cmpq	$0, 80(%rsp)
	je	.L97
	movq	64(%rsp), %rsi
	movq	80(%rsp), %rdi
	call	_ZdlPvm
.L97:
	movq	64(%rsp), %rbx
	cmpq	$0, 72(%rsp)
	je	.L98
	jmp	.L56
.L77:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
	jmp	.L70
.L95:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
	jmp	.L70
.L79:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
	jmp	.L70
.L81:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
	jmp	.L70
.L83:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
	jmp	.L70
.L85:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
	jmp	.L70
.L86:
	movq	32(%rsp), %rax
	movq	%r12, %r14
	movq	%rax, 40(%rsp)
	jmp	.L70
.L143:
	movl	$.LC16, %edi
	call	_ZSt20__throw_length_errorPKc
.LEHE14:
	.cfi_endproc
.LFE3404:
	.section	.gcc_except_table
.LLSDAC3404:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSEC3404-.LLSDACSBC3404
.LLSDACSBC3404:
	.uleb128 .LEHB14-.LCOLDB32
	.uleb128 .LEHE14-.LEHB14
	.uleb128 0
	.uleb128 0
.LLSDACSEC3404:
	.section	.text.unlikely
	.text
	.size	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE, .-_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE
	.section	.text.unlikely
	.size	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE.cold, .-_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE.cold
.LCOLDE32:
	.text
.LHOTE32:
	.section	.rodata.str1.1
.LC33:
	.string	"matrix_benchmark.csv"
	.section	.rodata.str1.8
	.align 8
.LC34:
	.string	"basic_string: construction from null is not valid"
	.section	.rodata.str1.1
.LC35:
	.string	"Error: could not open "
.LC36:
	.string	"matrix_size,"
.LC37:
	.string	"iterations,"
.LC38:
	.string	"average_ns,"
.LC39:
	.string	"minimum_ns,"
.LC40:
	.string	"maximum_ns,"
.LC41:
	.string	"variance_ns2,"
.LC42:
	.string	"stddev_ns\n"
	.section	.rodata.str1.8
	.align 8
.LC47:
	.string	"\nBenchmark results written to "
	.section	.text.unlikely
.LCOLDB48:
	.section	.text.startup,"ax",@progbits
.LHOTB48:
	.p2align 4
	.globl	main
	.type	main, @function
main:
.LFB3422:
	.cfi_startproc
	.cfi_personality 0x3,__gxx_personality_v0
	.cfi_lsda 0x3,.LLSDA3422
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
	jle	.L186
	movq	8(%rsi), %r12
	leaq	16(%rsp), %rbp
	movq	%rbp, (%rsp)
	testq	%r12, %r12
	je	.L182
	movq	%r12, %rdi
	call	strlen
	movq	%rax, 160(%rsp)
	movq	%rax, %rbx
	cmpq	$15, %rax
	ja	.L159
	cmpq	$1, %rax
	je	.L187
	movq	%rsp, %r14
	testq	%rax, %rax
	jne	.L188
.L164:
	movq	160(%rsp), %rax
	movq	(%rsp), %rdx
	movq	%rax, 8(%rsp)
	movb	$0, (%rdx,%rax)
.LEHB15:
	call	_Z15initialize_papiv
	movl	$1, %ebx
	testb	%al, %al
	je	.L165
	call	_Z23measure_timing_overheadv
	movl	$16, %edx
	movq	%r14, %rsi
	leaq	160(%rsp), %rdi
	call	_ZNSt14basic_ofstreamIcSt11char_traitsIcEEC1ERKNSt7__cxx1112basic_stringIcS1_SaIcEEESt13_Ios_Openmode
.LEHE15:
	leaq	272(%rsp), %rdi
	call	_ZNKSt12__basic_fileIcE7is_openEv
	testb	%al, %al
	je	.L189
	movl	$12, %edx
	movl	$.LC36, %esi
	leaq	160(%rsp), %rdi
.LEHB16:
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
	movl	$11, %edx
	movl	$.LC40, %esi
	leaq	160(%rsp), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$13, %edx
	movl	$.LC41, %esi
	leaq	160(%rsp), %rdi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$.LC42, %esi
	leaq	160(%rsp), %rdi
	call	_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
	leaq	40(%rsp), %rdi
	movl	$10, %ecx
	leaq	32(%rsp), %r13
	movq	160(%rsp), %rax
	leaq	160(%rsp), %rdx
	leaq	80(%rsp), %r15
	movdqa	.LC43(%rip), %xmm0
	movq	$512, 144(%rsp)
	addq	-24(%rax), %rdx
	leaq	152(%rsp), %r12
	movq	$100, 32(%rsp)
	movl	24(%rdx), %eax
	movaps	%xmm0, 80(%rsp)
	movdqa	.LC44(%rip), %xmm0
	movq	$3, 8(%rdx)
	andl	$-261, %eax
	movaps	%xmm0, 96(%rsp)
	movdqa	.LC45(%rip), %xmm0
	orl	$4, %eax
	movl	%eax, 24(%rdx)
	xorl	%eax, %eax
	rep stosl
	movaps	%xmm0, 112(%rsp)
	movdqa	.LC46(%rip), %xmm0
	movaps	%xmm0, 128(%rsp)
	.p2align 4
	.p2align 3
.L168:
	movq	0(%r13), %rbp
	movq	%r15, %rbx
	.p2align 4
	.p2align 3
.L169:
	movq	(%rbx), %rdi
	leaq	160(%rsp), %rdx
	movq	%rbp, %rsi
	call	_Z12benchmark_mmmmRSt14basic_ofstreamIcSt11char_traitsIcEE
	addq	$8, %rbx
	cmpq	%rbx, %r12
	jne	.L169
	addq	$8, %r13
	cmpq	%r15, %r13
	jne	.L168
	leaq	160(%rsp), %rdi
	call	_ZNSt14basic_ofstreamIcSt11char_traitsIcEE5closeEv
	movl	$30, %edx
	movl	$.LC47, %esi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	8(%rsp), %rdx
	movq	(%rsp), %rsi
	movl	$_ZSt4cout, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$.LC2, %esi
	movq	%rax, %rdi
	call	_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
	call	PAPI_shutdown
.LEHE16:
	xorl	%ebx, %ebx
.L167:
	leaq	160(%rsp), %rdi
	call	_ZNSt14basic_ofstreamIcSt11char_traitsIcEED1Ev
.L165:
	movq	%r14, %rdi
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
.L187:
	.cfi_restore_state
	movzbl	(%r12), %eax
	movq	%rsp, %r14
	movb	%al, 16(%rsp)
	jmp	.L164
.L186:
	leaq	16(%rsp), %rax
	movl	$20, %ebx
	movq	$20, 160(%rsp)
	movl	$.LC33, %r12d
	movq	%rax, (%rsp)
.L159:
	movq	%rsp, %rdi
	leaq	160(%rsp), %rsi
	xorl	%edx, %edx
	movq	%rsp, %r14
.LEHB17:
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm
.LEHE17:
	movq	%rax, (%rsp)
	movq	%rax, %rdi
	movq	160(%rsp), %rax
	movq	%rax, 16(%rsp)
.L162:
	movq	%rbx, %rdx
	movq	%r12, %rsi
	call	memcpy
	jmp	.L164
.L189:
	movl	$22, %edx
	movl	$.LC35, %esi
	movl	$_ZSt4cerr, %edi
.LEHB18:
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movq	8(%rsp), %rdx
	movq	(%rsp), %rsi
	movl	$_ZSt4cerr, %edi
	call	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l
	movl	$.LC2, %esi
	movq	%rax, %rdi
	call	_ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
	call	PAPI_shutdown
.LEHE18:
	movl	$1, %ebx
	jmp	.L167
.L188:
	movq	%rbp, %rdi
	jmp	.L162
.L175:
	movq	%rax, %rbx
	jmp	.L172
.L176:
	movq	%rax, %rbx
	jmp	.L171
	.section	.gcc_except_table
.LLSDA3422:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSE3422-.LLSDACSB3422
.LLSDACSB3422:
	.uleb128 .LEHB15-.LFB3422
	.uleb128 .LEHE15-.LEHB15
	.uleb128 .L175-.LFB3422
	.uleb128 0
	.uleb128 .LEHB16-.LFB3422
	.uleb128 .LEHE16-.LEHB16
	.uleb128 .L176-.LFB3422
	.uleb128 0
	.uleb128 .LEHB17-.LFB3422
	.uleb128 .LEHE17-.LEHB17
	.uleb128 0
	.uleb128 0
	.uleb128 .LEHB18-.LFB3422
	.uleb128 .LEHE18-.LEHB18
	.uleb128 .L176-.LFB3422
	.uleb128 0
.LLSDACSE3422:
	.section	.text.startup
	.cfi_endproc
	.section	.text.unlikely
	.cfi_startproc
	.cfi_personality 0x3,__gxx_personality_v0
	.cfi_lsda 0x3,.LLSDAC3422
	.type	main.cold, @function
main.cold:
.LFSB3422:
.L182:
	.cfi_def_cfa_offset 736
	.cfi_offset 3, -56
	.cfi_offset 6, -48
	.cfi_offset 12, -40
	.cfi_offset 13, -32
	.cfi_offset 14, -24
	.cfi_offset 15, -16
	movl	$.LC34, %edi
.LEHB19:
	call	_ZSt19__throw_logic_errorPKc
.L171:
	leaq	160(%rsp), %rdi
	call	_ZNSt14basic_ofstreamIcSt11char_traitsIcEED1Ev
.L172:
	movq	%r14, %rdi
	call	_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_disposeEv
	movq	%rbx, %rdi
	call	_Unwind_Resume
.LEHE19:
	.cfi_endproc
.LFE3422:
	.section	.gcc_except_table
.LLSDAC3422:
	.byte	0xff
	.byte	0xff
	.byte	0x1
	.uleb128 .LLSDACSEC3422-.LLSDACSBC3422
.LLSDACSBC3422:
	.uleb128 .LEHB19-.LCOLDB48
	.uleb128 .LEHE19-.LEHB19
	.uleb128 0
	.uleb128 0
.LLSDACSEC3422:
	.section	.text.unlikely
	.section	.text.startup
	.size	main, .-main
	.section	.text.unlikely
	.size	main.cold, .-main.cold
.LCOLDE48:
	.section	.text.startup
.LHOTE48:
	.section	.rodata.cst16,"aM",@progbits,16
	.align 16
.LC8:
	.long	0
	.long	1
	.long	2
	.long	3
	.section	.rodata.cst8,"aM",@progbits,8
	.align 8
.LC21:
	.long	0
	.long	1104006501
	.section	.rodata.cst16
	.align 16
.LC43:
	.quad	2
	.quad	4
	.align 16
.LC44:
	.quad	8
	.quad	16
	.align 16
.LC45:
	.quad	32
	.quad	64
	.align 16
.LC46:
	.quad	128
	.quad	256
	.globl	__gxx_personality_v0
	.ident	"GCC: (GNU) 15.2.1 20251117"
	.section	.note.GNU-stack,"",@progbits
