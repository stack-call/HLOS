
    //jmp .
.globl startup_32
startup_32:
	movl $0x10, %eax					# 对于GNU汇编,每个直接操作数要以'$'开始,否则表示地址.每个寄存器名都要以'$'开头,eax表示是32位的ax寄存器.
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
    jmp .
	lss stack_start, %esp				# 表示stack_start->ss:esp,设置系统堆栈.stack_start定义在kernel/sched.c中.
	call setup_idt						# 调用设置中断描述符表子程序.
	call setup_gdt						# 调用设置全局描述符表子程序.
	movl $0x10, %eax					# reload all the segment registers
	mov %ax, %ds						# after changing gdt. CS was already
	mov %ax, %es						# reloaded in 'setup_gdt'
	mov %ax, %fs						# 因为修改了gdt,所以需要重新装载所有的段寄存器.CS代码段寄存器已经在setup_gdt中重新加载过了.
	mov %ax, %gs