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

go: 

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