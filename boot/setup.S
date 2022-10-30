
.code16

.text

.global _start
_start:
# now we want to move to protected mode ...
# 现在我们要进入保护模式中了...

	cli											# no interrupts allowed !	! 从此开始不允许中断.

	# first we move the system to it's rightful place
	# 首先我们将system模块移到正确的位置.
	# bootsect引导程序会把system模块读入到内存0x10000(64KB)开始的位置.由于当时假设system模块最大长度不会超过0x80000(512KB),即其
	# 末端不会超过内存地址0x90000,所以bootsect会把自己移动到0x90000开始的地方,并把setup加载到它的后面.下面这段程序的用途是把整个
	# system模块移动到0x00000位置,即把从0x10000到0x8ffff的内存数据块(512KB)整块地向内存低端移动了0x10000(64KB)的位置.

	mov	$0x0, %ax
	cld				# 'direction'=0, movs moves forward
do_move:
	mov	%ax, %es		# destination segment	# es:di是目的地址(初始为0x0:0x0)
	add	$0x1000, %ax
	cmp	$0x9000, %ax		# 已经把最后一段(从0x8000段开始的64KB)代码移动完.
	jz	end_move		# 是,则跳转.
	mov	%ax, %ds		# source segment	! ds:si是源地址(初始为0x1000:0x0)
	sub	%di, %di
	sub	%si, %si
	mov $0x8000, %cx		# 移动0x8000字(64KB).
	rep
	movsw
	jmp	do_move

	# then we load the segment descriptors
	# 此后,我们加载段描述符.
	#
	# 下面指令lidt用于加载中断描述符表(IDT)寄存器.它的操作数(idt_48)有6个字节.前2个字节(字节0-1)是描述符表的字节长度值;后4字节(字节2-5)是描述符表
	# 的32位线性基地址.中断描述符表中的每一个8字节表项指出发生中断时需要调用的代码信息.与中断向量有些相似,但要包含更多的信息.
	#
	# lgdt指令用于加载全局描述符表(GDT)寄存器,其操作数格式与lidt指令的相同.全局描述符表中的每个符项(8字节)描述了保护模式下数据段和代码段(块)的信息.其
	# 中包括段的最大长限制(16位),段的线性地址基址(32位)/段的特权级,段是否在内存,读写许可权以及其他一些保护模式运行的标志.
end_move:

      //ljmp $0x0, $0x0
    #开启A20
    in $0x92, %al
    or $0x2, %al
    out %al, $0x92

    #加载GDT
    mov	$0x9020, %ax
    mov %ax, %ds

    lidt idt_48
    lgdt gdt_48

# .word	0x00eb,0x00eb是直接使用机器码表示的两条相对跳转指令,起延时作用.0xeb是直接近跳转指令的操作码,带1个字节的相对位移值.因此跳转范围是
# -127--127.CPU通过把这个相对位移值加到EIP寄存器中就形成一个新的有效地址.此时EIP指向下一条被执行的指令.执行时所花费的CPU时钟周期数是7至10
# 个.0x00eb表示跳转值是0的一条指令,因此还是直接执行下一条指令.这两条指令共可提供14--20个CPU时钟周期的延迟时间.在as86上没有表示相应指令的助
# 记符,因此Linus在setup.s等一些汇编程序中就直接使用机器码来表示这种指令.另外,每个空操作指令NOP的时钟周期数是3个,因此若要达到相同的延迟效果
# 就需要6~7个NOP指令.

# 8259芯片主片端口是0x20-0x21,从片端口是0xA0-0xA1.输出值0x11表示初始化命令开始,它是ICW1命令字,表示边沿触发,多片8269级连,最后要发送ICW4
# 命令字.

	mov	$0x11, %al							# initialization sequence
	out	%al, $0x20								# send it to 8259A-1	! 发送到8259A主芯片.
	.word	0x00eb, 0x00eb						# jmp $+2, jmp $+2	! '$'表示当前指令的地址.
	out	%al, $0xA0							# and to 8259A-2	! 再发送到8259A从芯片.
	.word	0x00eb, 0x00eb
	# Linux系统硬件中断号被设置成从0x20开始.
	mov	$0x20, %al							# start of hardware int's (0x20)
	out	%al, $0x21							# 送主芯片ICW2命令字,设置起始中断号,要送奇端口.
	.word	0x00eb, 0x00eb
	mov	$0x28, %al							# start of hardware int's 2 (0x28)
	out	%al, $0xA1 							# 送从芯片ICW2命令字,从芯片的起始中断号.
	.word	0x00eb, 0x00eb

	mov	$0x04, %al								# 8259-1 is master
	out	%al, $0x21								# 送主芯片ICW3命令字,主芯片的IR2连从芯片INT.
	.word	0x00eb, 0x00eb
	mov	$0x02, %al							# 8259-2 is slave
	out	%al, $0xA1							# 送从芯片ICW3命令字,主芯片的IR2连从芯片的INT连到主芯片的IR2引脚上.

	.word	0x00eb, 0x00eb
	mov	$0x01, %al							# 8086 mode for both
	out	%al,$0x21							# 送主芯片ICW4命令字.8086模式;普通EOI,非缓冲方式,需发送指令来.初始化结束,芯片就绪.
	.word	0x00eb, 0x00eb
	out	%al, $0xA1								# 送从芯片ICW4命令字,内容同上.
	.word	0x00eb, 0x00eb
	mov	$0xFF, %al								# mask off all interrupts for now
	out	%al, $0x21								# 屏蔽主芯片所有中断请求.
	.word	0x00eb, 0x00eb
	out	%al, $0xA1								# 屏蔽从芯片所有中断请求.

    mov %cr0, %eax
    or $0x00000001, %eax
    mov %eax, %cr0

    ljmp $0x8, $0x0



# -------------------------------------------------------------------------------
# 功能:读取硬盘n个扇区
# rd_disk_m_32:	   
#-------------------------------------------------------------------------------
				       # eax=LBA扇区号
				       # ds:ebx=将数据写入的内存地址(可以修改)
				       # ecx=读入的扇区数
      movl %eax, %esi	  #备份eax
      movw %cx, %di		  #备份cx
#读写硬盘:
#第1步：设置要读取的扇区数
      movw $0x1f2, %dx
      mov %cl, %al
      out %al, %dx            #读取的扇区数
      movl %esi, %eax	   #恢复ax

#第2步：将LBA地址存入0x1f3 ~ 0x1f6

      #LBA地址7~0位写入端口0x1f3
      movw $0x1f3, %dx                       
      out %al, %dx                        

      #LBA地址15~8位写入端口0x1f4
      movb $8, %cl
      shr %cl, %eax
      movw $0x1f4, %dx
      out %al, %dx

      #LBA地址23~16位写入端口0x1f5
      shr %cl, %eax
      movw $0x1f5, %dx
      out %al, %dx

      shr %cl, %eax
      and $0x0f, %al	   #lba第24~27位
      or $0xe0, %al	   # 设置7～4位为1110,表示lba模式
      mov $0x1f6, %dx
      out %al, %dx

#第3步：向0x1f7端口写入读命令，0x20 
      mov $0x1f7, %dx
      mov $0x20, %al                        
      out %al, %dx

#第4步：检测硬盘状态
  .not_ready:
      #同一端口，写时表示写入命令字，读时表示读入硬盘状态
      nop
      in %dx, %al
      and $0x88, %al	   #第4位为1表示硬盘控制器已准备好数据传输，第7位为1表示硬盘忙
      cmp $0x08, %al
      jnz .not_ready	   #若未准备好，继续等。

#第5步：从0x1f0端口读数据
      mov %di, %ax
      mov $256, %dx
      mul %dx
      mov %ax, %cx	   # di为要读取的扇区数，一个扇区有512字节，每次读入一个字，
			   # 共需di*512/2次，所以di*256
      mov $0x1f0, %dx
  .go_on_read:
      in %dx, %ax
      mov %ax, (ebx) #与16位程序只有这里不同
      add $2, %ebx		  
      loop .go_on_read
      ret


# 全局描述符表开始处.描述符表由多个8字节长的描述符项组成.这里给出了3个描述符项.
# 第1项无用,但须存在.第2项的系统代码段描述符,第3项是系统数据段描述符.
gdt:
	.word	0, 0, 0, 0						# dummy	# 第1个描述符,不用.

	# 在GDT表 这里的偏移量是0x08.它是内核代码段选择符的值.
	.word	0x07FF							# 8Mb - limit=2047 (2048*4096=8Mb)	# (0~2047,因此是2048*4096B=8MB)
	.word	0x0000							# base address=0
	.word	0x9A00							# code read/exec			# 代码段为只读,可执行.
	.word	0x00C0							# granularity=4096, 386			# 颗粒度为4096,32位模式.

	# 在GDT表中这里的偏移量是0x10,它是内核数据段选择符的值.
	.word	0x07FF							# 8Mb - limit=2047 (2048*4096=8Mb)	# (2048*4096B=8MB)
	.word	0x0000							# base address=0
	.word	0x9200							# data read/write			# 数据段为可读可写.
	.word	0x00C0							# granularity=4096, 386			# 颗粒度为4096,32位模式.

# 下面是加载中断描述符表寄存器idtr的指令lidt要求的6字节操作数.前2字节的IDT 的限长,后4字节是idt表在线性地址空间中的32位基地址.CPU要求在进入
# 保护模式之前需设置IDT表,因此这里先设置一个长度为0的空表.
idt_48:
	.word	0								# idt limit=0
	.word	0, 0							# idt base=0L

# 这是加载全局描述符表寄存器gdtr的指令lgdt要求的6字节操作数.前2字节是gdt的限长,后4字节是gdt表的线性基地址.这里全局表长度设置为2KB(0x7ff即可),
# 因为每8字节组成一个段描述符项,所以表中共可有256面.4字节的线性基地址为0x0009<<16+0x0200+gdt,即0x90200+gdt.(符号gdt是全局表在本 段中的偏移地址)
gdt_48:
	.word	0x800							# gdt limit=2048, 256 GDT entries
	.word	512 + gdt, 0x9					# gdt base = 0X9xxxx