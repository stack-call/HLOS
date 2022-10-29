include Makefile.header

all: Image

Image: boot/bootsect boot/setup tools/system
	cp ./tools/hd60M.img ./
	dd if=boot/bootsect of=hd60M.img bs=512 count=1 seek=0 conv=notrunc
	dd if=boot/setup of=hd60M.img bs=512 count=4 seek=1 conv=notrunc
	dd if=tools/system of=hd60M.img bs=512 count=1 seek=5 conv=notrunc



tools/system:boot/bootsect boot/setup boot/head.o sched.o
	$(LD) $(LDFLAGS) boot/head.o sched.o -Ttext 0x0 -e startup_32 -o system.tmp
	$(OBJCOPY) $(OBJCOPYFLAGS) system.tmp tools/system

boot/bootsect: boot/bootsect.S
	make bootsect -C boot

boot/setup: boot/setup.S
	make setup -C boot

boot/head.o: boot/head.S
	make head.o -C boot

sched.o: ./kernel/sched.c
	$(CC) $(CFLAGS) ./kernel/sched.c -o sched.o

clean:
	make clean -C boot
	rm ./tools/system sched.o system.tmp hd60M.img

bochs:
	bochs -f HLOS_bochsrc