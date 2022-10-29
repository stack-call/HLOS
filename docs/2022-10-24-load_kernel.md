# 加载操作系统内核

## 需要完成的任务
* 1.加载setup
* 2.加载system
* 3.获取相关参数信息
* 4.设置GDT,打开A20,加载gdt,cr0的pe置位,进入保护模式
* 5.设置页表，打开分页

linux在bootsect中加载setup和system  
在setup中获取相关参数并进入保护模式
在system中设置分页并跳转main




## 准备
最头痛的问题是linux代码中感觉都是针对软盘的加载代码，需要大量修改。
### 硬盘参数表
在PC机中BIOS设定的中断向量表中int 0x41的中断向量位置(4*0x41 =
     0x0000:0x0104)存放的并不是中断程序的地址,而是第一个硬盘的基本参数表
     对于100%兼容的BIOS来说,这里存放着硬盘参数表阵列的首地址0xF000:0E401
     第二个硬盘的基本参数表入口地址存于int 0x46中断向量位置处.每个硬盘参
     数表有16个字节大小.
[硬盘参数表](https://blog.csdn.net/aona1925/article/details/101671557) 或 [硬盘参数表](https://www.cnblogs.com/Mr-Shadow/archive/2013/02/02/2890367.html)
### 读取硬盘中断
```
SECTION code16 vstart=0x7c00;(也可以是ORG 0x7c00)

;此时cs = 0, ip = 0x7c00
;把所有的段寄存器全部修改为0x0，则只需要关注偏移
mov ax, cs
mov ds, ax
mov ss, ax
mov fs, ax
mov es, ax
mov sp, 0x7c00

;接下来是系统调用测试
load_setup:
	xor	dx, dx
    mov dl, 0x80  ;注意这里
	mov	cx, 0x0002
	mov	bx, 0x0200
	mov	ax, 0x0204
	int	0x13
	jnc	ok_load_setup
    jmp load_setup

ok_load_setup:

jmp $

message DB "hello"
times 510-($-$$) db 0
db 0x55, 0xaa
```
因为对linux bootsect.S中的源码疑惑，linux中读磁盘的系统调用一直是dl为0,即读软盘,我使用的硬盘，因此在bochs调试测试时一直没有走出load_setup的循环，说明没有成功读取，但是当dl修改为硬盘时读取成功。

PS:如果实在不行就直接使用硬盘寄存器操作硬盘而不使用中断。
## 第一扇区512字节
bootsect.S
```asm
#include <linux/config.h>

SETUPSECS = 4
BOOTSEG   = 0x07C0
INITSEG   = DEF_INITSEG
SETUPSEG  = DEF_SETUPSEG
SYSSEG    = DEF_SYSSEG		


.code16

.text

.global _start
_start:

	movw	$BOOTSEG, %ax
	movw	%ax, %ds
	movw	$INITSEG, %ax
	movw	%ax, %es
	movw	$256, %cx
	subw	%si, %si
	subw	%di, %di
	cld
	rep
	movsw
	ljmp	$INITSEG, $go
      #这个是必须的，因为编译时起始地址为0x0，因此段基址需要为0x7c00
      #否则其中值的地址就是以0为开头的，是错误的
      #使用长跳修改CS寄存器的值(不能直接修改)

go:

# 以下代码的用途是利用ROM BIOS中断INT 0x13将setup模块从磁盘第2个扇区开始读到0x90200开始处，共读4个扇区。在读操作过程中如果读出错，则显示
# 磁盘上出错扇区位置,然后复位驱动器并重试,没有退路.
# INT 0x13读扇区使用调用参数设置如下:
# ah = 0x02  读磁盘扇区到内存		al = 需要读出的扇区数量;
# ch = 磁道(柱面)号的低8位;		cl = 开始扇区(位0~5),磁道号高2位(位6~7);
# dh = 磁头号；				dl = 驱动器号（如果是硬盘则位7要置位）；
# es:bx 指向数据缓冲区;	如果出错则CF标志置位,ah中是出错码.
load_setup:
	xorw	%dx, %dx			# drive 0, head 0
	movw  $0x0002, %cx		# sector 2, track 0
      movb  $0x80, %dl
	movw  $0x0200, %bx		# address = 512, in INITSEG
	movw  $0x0200 + 4, %ax		# service 2, nr of sectors
	int   $0x13			      # read it

	jnc ok_load_setup

	jmp	load_setup

ok_load_setup:

      mov $SYSSEG, %ax
      mov %ax, %es
	xorw	%dx, %dx			# drive 0, head 0
	movw  $0x0006, %cx		# sector 2, track 0
      movb  $0x80, %dl
	movw  $0x0, %bx		# address = 512, in INITSEG
	movw  $0x0200 + 1, %ax		# service 2, nr of sectors
	int   $0x13	

#为了与使用中断读取保持一致，读取到SYSSEG段
/*
      mov $SYSSEG, %ax
      mov %ax, %es
      mov %ax, %ds
      mov $0x5, %eax
      mov $0x0, %bx
      mov $1, %cx  #先用1测试
      call rd_disk_m_16

*/
      ljmp $INITSEG,$0x200

# 因为实模式的段最多16bit，即64K大小，因此需要不断判断是否大于64k
# 需要像Linux中的那样不断判断还需要读取多少
# 如果进入保护模式再读取又可能损坏了某些信息
# 但是在保护模式读取会很简单
# 因此直接读取硬盘寄存器来读取AT硬盘的扇区(xv6使用的方式,修改自真相还原)
#以下代码使用LBA而不是CHS
# -------------------------------------------------------------------------------
# 功能:读取硬盘n个扇区
rd_disk_m_16:	   
#-------------------------------------------------------------------------------
				       # eax=LBA扇区号
				       # es:(e)bx=将数据写入的内存地址(可以修改代码)
				       # (e)cx=读入的扇区数
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
      mov %ax, %es:(%bx)
      add $2, %bx		  
      loop .go_on_read
      ret

.org 510
.byte 0x55, 0xaa
```

setup.S
```

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
    mov %cr0, %eax
    or $0x00000001, %eax
    mov %eax, %cr0

    ljmp $0x8, $0x0



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
```

head.S
```

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
	jmp .

setup_gdt:
	lgdt gdt_descr					# 加载全局描述符表寄存器(内容已设置好)
	ret


 # 下面是加载全局描述符表寄存器gdtr的指令lgdt要求的6字节操作数.前2字节是gdt表的限长,后4字节是gdt表的线性基地址.这里全局表长度设置为
 # 2KB字节(0x7ff即可),因为每8字节组成一个描述符项,所以表中共可有256项.符号gdt是全局表在本程序中的偏移位置.

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

```