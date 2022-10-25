# 加载操作系统内核

最头痛的问题是linux代码中感觉都是针对软盘的加载代码，需要大量修改。
## 准备
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
```asm title="bootsect.S"

```