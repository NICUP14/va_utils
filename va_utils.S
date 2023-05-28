.data
_va_param_off: .long 16

.text
.global _va_start
.global _va_arg

# NOTE: This implementation only works on UNIX x86_64 systems.

/*
	// Minimalistic va_list implementation
	// There's no way to rewind va_list (just as Stallman intended)
	struct va_list
	{
		uint64 arg_i;
		void* reg_param_ptr; // Saved by caller (printf)
		void* stack_param_ptr; // Saved by caller's caller (main)
	};
*/

# Push values in reverse order
.macro push_reg_state
	push %r9
	push %r8
	push %rcx
	push %rdx
	push %rsi
	push %rdi
.endm

.macro pop_reg_state
	pop %rdi
	pop %rsi
	pop %rdx
	pop %rcx
	pop %r8
	pop %r9
.endm

# @brief Calculates the rsp offset from 2 base pointers (rbp_fun, rbp_parent)
# @param callee_rbp Represents the rbp of the function (rbp_fun)
# @param caller_rbp Represents the rbp of the parent function (rbp_parent)
.macro get_caller_rsp_off callee_rbp, caller_rbp
	mov \caller_rbp, %rax
	mov \callee_rbp, %rcx
	sub %rcx, %rax
.endm

_va_start:

	# @param rdi- va_list (void*)

	push %rbp
	mov %rsp, %rbp

	movq $0, (%rdi)

	# reg_param_ptr
	mov (%rbp), %rdx # rdx = rbp_old
	get_caller_rsp_off %rbp, %rdx # rax = rsp_off
	add _va_param_off(%rip), %rdx # skip caller's return addr and rbp
	sub %rax, %rdx # add rsp_off, rdx = rsp_old
	mov %rdx, 8(%rdi) # va_list.reg_param_ptr = rdx = rsp_old

	# stack_param_ptr (rdx)
	mov (%rbp), %rax # rax = rbp_old
	mov (%rax), %rdx # rdx = *rax = rbp_old_old
	get_caller_rsp_off (%rbp), %rdx
	add _va_param_off(%rip), %rdx # skip caller's caller return addr and rbp
	sub %rax, %rdx
	mov %rdx, 16(%rdi) # va_list.stack_param_ptr = rdx = rsp_old

	leave
	ret

_va_arg:

	# @param rdi - va_list (void*)
	# @return the requested arg (uint64)

	push %rbp
	mov %rsp, %rbp

	cmpq $6, (%rdi)
	jge use_stack_ptr
	mov 8(%rdi), %rbx
	mov (%rdi), %rcx
	jmp _va_arg_end
	use_stack_ptr:
	mov 16(%rdi), %rbx
	mov (%rdi), %rcx
	sub $6, %rcx

	_va_arg_end:
	mov (%rbx, %rcx, 8), %rax
	incq (%rdi)

	leave
	ret
