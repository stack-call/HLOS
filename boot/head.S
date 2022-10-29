
    //jmp .
.text

.globl startup_32
startup_32:
	movl $0x10, %eax					# 对于GNU汇编,每个直接操作数要以'$'开始,否则表示地址.每个寄存器名都要以'$'开头,eax表示是32位的ax寄存器.
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
    //jmp .
	//lss stack_start, %esp				# 表示stack_start->ss:esp,设置系统堆栈.stack_start定义在kernel/sched.c中.
	mov %ax, %ss
	mov $user_stack+4095, %esp
	//call setup_idt						# 调用设置中断描述符表子程序.
	call setup_gdt						# 调用设置全局描述符表子程序.
	ljmp $0x08, $1f
1:
	movl $0x10, %eax					# reload all the segment registers
	mov %ax, %ds						# after changing gdt. CS was already
	mov %ax, %es						# reloaded in 'setup_gdt'
	mov %ax, %fs						# 因为修改了gdt,所以需要重新装载所有的段寄存器.CS代码段寄存器已经在setup_gdt中重新加载过了.
	mov %ax, %gs
	# 由于段描述符中的段限长从setup.s中的8MB改成了本程序设置的16MB,因此这里再次对所有段寄存器执行加载操作是必须的.另外,通过使用bochs跟踪观察,如果不对
	# CS再次执行加载,那么在执行到movl $0x10,%eax时CS代码段不可见部分中的限长还是8MB.这样看来应该重新加载CS.但是由于setup.s中的内核代码段描述符与本
	# 程序中重新设置的代码段描述符除了段限长以外其余部分完全一样,8MB的限长在内核初始化阶段不会有问题,而且在以后内核执行过程中段间跳转时会重新加载CS.因此
	# 这里没有加载它并没有让程序出错.针对该问题,目前内核中就在call setup_gdt之后添加了一条长跳转指令:'ljmp $(__KERNEL_CS),$1f',跳转到movl $0x10,$eax
	# 来确保CS确实被重新加载.

	//lss stack_start, %esp
	mov %ax, %ss
	mov $user_stack+4095, %esp

	mov $0xb8000, %eax
	mov 0x45, %bl
	mov 0x45, %bh
	mov %bx, (%eax)

check_A20:
	xorl %eax, %eax
1:	incl %eax							# check that A20 really IS enabled
	 # '1:'是一个局部符号构成的标号.标号由符号后跟一个冒号组成.此时该符号表示活动位置计数的当前值,并可以作为指令的操作数.局部符号用于帮助编译器和编程人员临时
	 # 使用一些名称.共有10个局部符号名,可在整个程序中重复使用.这些符号名使用名称'0','1',...,'9'来引用.为了定义一个局部符号,需把标号写成'N:'形式(其中N表示
	 # 一个数字).为了引用先前最近定义的这个符号,需要写成'Nb',其中N是定义标号时使用的数字.为了引用一个局部标号的下一个定义,而要与成'Nf',这里N是10个前向引用
	 # 之一.上面'b'表示"向后(backwards)",'f'表示"向前(forwards)".在汇编程序的某一处,我们最大可以向后/向前引用10个标号.
	movl %eax, 0x000000					# loop forever if it isn't
	cmpl %eax, 0x100000
	je 1b



	jmp .

setup_gdt:
	lgdt gdt_descr					# 加载全局描述符表寄存器(内容已设置好)
	ret
/*
 * Linus将内核的内存页表直接放在页目录之后,使用了4个表来寻址16MB的物理内存.如果你有多于16MB的内存,就需要在这里进行扩充修改.
 *
 */
 # 每个页表长为4KB字节(1页内存页面),而每个页表项需要4个字节,因此一个页表共可以存放1024个表项.如果一个页表项寻址4KB的地址空间,则一个页表就可以寻址
 # 4MB的物理内存.
 # 页表项的格式为:项的前0-11位存放一些标志,例如是否在内存中(P位0),读写许可(R/W位1),普通还是超级用户使用(U/S位2),是否修改过了(是否脏了)(D位6)等;
 # 表项的位12-31是页框地址,用于指出一页内存的物理起始地址.

.org 0x1000							# 从偏移0x1000处开始的第1个页表(偏移0开始处将存放页表目录).
pg0:

.org 0x2000
pg1:

.org 0x3000
pg2:

.org 0x4000
pg3:

.org 0x5000							# 定义下面的内存数据块从偏移0x5000处开始.

 # 下面是加载全局描述符表寄存器gdtr的指令lgdt要求的6字节操作数.前2字节是gdt表的限长,后4字节是gdt表的线性基地址.这里全局表长度设置为
 # 2KB字节(0x7ff即可),因为每8字节组成一个描述符项,所以表中共可有256项.符号gdt是全局表在本程序中的偏移位置.
.align 2
.word 0
gdt_descr:
	.word 256 * 8 - 1					# so does gdt (not that that's any
	.long gdt							# magic number, but it works for me :^)

 # 全局表,前4项分别是空项(不用),代码段描述符,数据段描述符,系统调用段描述符,其中系统调用段描述符并没有派用处,Linus当时可能曾想把系统调用
 # 代码专门放在这个独立的段中.
 # 同还预留了252项的空间,用于放置所创建任务的局部描述符(LDT)和对应的任务状态段TSS的描述符.
 # (0-nul, 1-cs, 2-ds, 3-syscall, 4-TSS0, 5-LDT0, 6-TSS1, 7-LDT1, 8-TSS2 etc...)
gdt:
	.quad 0x0000000000000000			/* NULL descriptor */
	.quad 0x00c09a0000000fff			/* 16Mb */		# 0x08,内核代码段最大长度16MB.
	.quad 0x00c0920000000fff			/* 16Mb */		# 0x10,内核数据段最大长度16MB.
	.quad 0x0000000000000000			/* TEMPORARY - don't use */
	.fill 252, 8, 0						/* space for LDT's and TSS's etc */	# 预留空间.
