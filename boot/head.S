
    //jmp .
.text
.globl idt,gdt,pg_dir
pg_dir:# 页目录将会存放在这里.

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

	jmp after_page_tables


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

after_page_tables:
	pushl $0						# These are the parameters to main :-)
	pushl $0						# 这些是调用main程序的参数(指init/main.c).
	pushl $0						# 其中的'$'符号表示这是一个立即操作数.
	pushl $L6						# return address for main, if it decides to.
	pushl $main						# 'main'是编译程序对main的内部表示方法.
	jmp setup_paging				# 跳转至setup_paging
L6:
	jmp L6							# main should never return here, but
									# just in case, we know what happens.
									# main程序绝对不应该返回到这里.不过为了以防万一,所以添加了该语句.这样我们就知道发生什么问题了.

/*
 * 这个子程序通过设置控制寄存器cr0的标志(PG位31)来启动对内存的分页处理功能,并设置各个页表项的内容,以恒等映射前16MB的物理内存.分页器假定
 * 不会产生非法的地址映射(也即在只有4MB的机器上设置出大于4MB的内存地址).
 *
 * 注意!尽管所有的物理地址都应该由这个子程序进行恒等映射,但只有内核页面管理函数能直接使用>1MB的地址.所有"普通"函数仅使用低于1MB的地址空间,
 * 或者是使用局部数据空间,该地址空间将被映射到其他一些地方去--mm(内存管理程序)会管理这些事的.
 *
 */
 # 上面英文注释第2段的含义是指在机器物理内存中大于1MB的内存空间主要被用于主内存区.主内存区空间由mm模块管理.它涉及页面映射操作.内核中所有其
 # 它函数就是这里指的一般(普通)函数.若要使用主内存区的页面,就需要使用get_free_page()等函数获取.因为主内存区中内存页面是共享资源,必须有
 # 进行统一管理以避免资源争用和竞争.
 #
 # 在内存物理地址0x0处开始存放1页页目录表和4页页表.页目录表是系统所有进程共用的,而这里的4页页表则属于内核专用,它们一一映射线性地址起始16MB
 # 空间范围到物理内存上.对于新的进程,系统会在主内存区为其申请页面存放页表.另外,1页内存长度是4096字节.

.align 2								# 按4字节方式对齐内存地址边界.
setup_paging:							# 首先对5页内存(1页目录+4页页表)清零.
	movl $1024 * 5, %ecx				/* 5 pages - pg_dir+4 page tables */
	xorl %eax, %eax
	xorl %edi, %edi						/* pg_dir is at 0x000 */	# 页目录从0x0000地址开始
	cld;rep;stosl						# eax内容存到es:edi所指内存位置处,且edi增4.

	 # 下面4句设置页目录表中的项,因为我们(内核)共有4个页表所以只需设置4项.
	 # 页目录项的结构与页表项的结构一样,4个字节为1项.
	 # 例如"$pg0+7"表示:0x00001007,是页目录表中的第1项.
	 # 则第1个页表所在的地址=0x00001007 & 0xfffff000=0x1000;
	 # 第1个页表的属性标志=0x00001007 & 0x00000fff = 0x07,表示该页存在,用户可读写.
	movl $pg0 + 7, pg_dir				/* set present bit/user r/w */
	movl $pg1 + 7, pg_dir + 4			/*  --------- " " --------- */
	movl $pg2 + 7, pg_dir + 8			/*  --------- " " --------- */
	movl $pg3 + 7, pg_dir + 12			/*  --------- " " --------- */

	 # 下面6行填写4个页表中所有项的内容,共有:4(页表)*1024(项/页表)=4096项(0-0xfff),即能映射物理内存4096*4KB = 16MB.
	 # 每项的内容是:当前项所映射的物理内存地址 + 该页的标志(这里均为7).
	 # 使用的方法是从最后一个页表的最后一项开始按倒退顺序填写.一个页表的最后一项在页表中的位置是1023*4 = 4092.因此最后一页的最后一项的位置就是$pg3+4092.

	movl $pg3 + 4092, %edi				# edi->最后一页的最后一项.
	movl $0xfff007, %eax				/*  16Mb - 4096 + 7 (r/w user,p) */
										# 最后一项对应物理内存页的地址是0xfff000,加上属性标志7,即为xfff007.
	std									# 方向位置位,edi值递减(4字节).
1:	stosl								/* fill pages backwards - more efficient :-) */
	subl $0x1000, %eax					# 每填好一项,物理地址值减0x1000.
	jge 1b								# 如果小于0则说明全填写好了.
	cld
	 # 设置页目录表基地址寄存器cr3的值,指向页目录表.cr3中保存的是页目录表的物理地址.
	xorl %eax, %eax						/* pg_dir is at 0x0000 */		# 页目录表在0x0000处.
	movl %eax, %cr3						/* cr3 - page directory start */
	 # 设置启动使用分页处理(cr0的PG标志,位31)
	movl %cr0, %eax
	orl $0x80000000, %eax				# 添上PG标志.
	movl %eax, %cr0						/* set paging (PG) bit */
	ret									/* this also flushes prefetch-queue */

# 在改变分页处理标志后要求使用转移指令刷新预取指令队列, 这里用的是返回指令ret.
# 该返回指令的另一个作用是将pushl $main压入堆栈中的main程序的地址弹出,并跳转到/init/main.c程序去运行.本程序到此就真正结束了.


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
