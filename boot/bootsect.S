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
	xorw	%dx, %dx						# drive 0, head 0
	movw $0x0002, %cx					# sector 2, track 0
	movw $0x0200, %bx					# address = 512, in INITSEG
	movw $0x0200 + SETUPLEN, %ax		# service 2, nr of sectors
	int	$0x13						# read it

	jnc ok_load_setup

	pushw	%ax			# dump error code
	call	print_nl
	movw	%sp, %bp
	call	print_hex
	popw	%ax
	jmp	load_setup

ok_load_setup:


# 因为实模式的段最多16bit，即64K大小，因此需要不断判断是否大于64k
# 需要像Linux中的那样不断判断还需要读取多少
# 如果进入保护模式再读取又可能损坏了某些信息
# 但是在保护模式读取会很简单
# 因此直接读取硬盘寄存器来读取AT硬盘的扇区(xv6使用的方式,修改自真相还原)

# -------------------------------------------------------------------------------
# 功能:读取硬盘n个扇区
# rd_disk_m_16:	   
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
      mov %ax, (bx)
      add $2, %bx		  
      loop .go_on_read
      ret
