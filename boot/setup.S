
.code16

.text

.global _start
_start:

    #开启A20
    in $0x92, %al
    or $0x2, %al
    out %al, $0x92

    #加载GDT
    mov	$0x9020, %ax
    mov %ax, %ds

    lidt idt_48
    lgdt gdt_48
    mov %cr0, %eax
    or $0x00000001, %eax
    mov %eax, %cr0

    ljmp $0x8,$90200
.code32

start32:
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $0x90000, %esp
    mov $0x18, %ax
    mov %ax, %gs
    mov %ax, %fs
loop:
    jmp loop


# -------------------------------------------------------------------------------
# 功能:读取硬盘n个扇区
# rd_disk_m_32:	   
#-------------------------------------------------------------------------------
				       # eax=LBA扇区号
				       # ebx=将数据写入的内存地址
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