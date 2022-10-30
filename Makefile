include Makefile.header

CFLAGS += -I ./include
LDFLAGS += -Ttext 0x0 -e startup_32
all: Image

Image: boot/bootsect boot/setup tools/system init/main.o
	cp ./tools/hd60M.img ./
	dd if=boot/bootsect of=hd60M.img bs=512 count=1 seek=0 conv=notrunc
	dd if=boot/setup of=hd60M.img bs=512 count=4 seek=1 conv=notrunc
	dd if=tools/system of=hd60M.img bs=512 count=128 seek=5 conv=notrunc
#注意写入的大小与编译结果大小和引导程序读取的统一!!!!!!!!!


tools/system:boot/bootsect boot/setup boot/head.o kernel/sched.o init/main.o
	$(LD) $(LDFLAGS) boot/head.o kernel/sched.o  -o system.tmp init/main.o 
	$(OBJCOPY) $(OBJCOPYFLAGS) system.tmp tools/system
#@echo -e "$(GREEN) $(LD) $(LDFLAGS) boot/head.o sched.o -Ttext 0x0 -e startup_32 -o system.tmp $(NONE)"
#链接时注意顺序，最前面的文件在.text段头部，例如head.o
boot/bootsect: boot/bootsect.S
	make bootsect -C boot

boot/setup: boot/setup.S
	make setup -C boot

boot/head.o: boot/head.S
	make head.o -C boot

init/main.o: init/main.c
	$(CC) $(CFLAGS) init/main.c -o init/main.o

kernel/sched.o: ./kernel/sched.c
	$(CC) $(CFLAGS) ./kernel/sched.c -o kernel/sched.o

clean:
	make clean -C boot
	rm ./tools/system kernel/sched.o system.tmp init/main.o hd60M.img

bochs:
	bochs -f HLOS_bochsrc