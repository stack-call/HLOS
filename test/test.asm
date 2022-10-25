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
    mov dl, 0x80
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