include ../Makefile.header

all:bootsect setup head ../tools/hd60M.img

	cp ../tools/hd60M.img ./
	dd if=bootsect of=hd60M.img bs=512 count=1 seek=0 conv=notrunc
	dd if=setup of=hd60M.img bs=512 count=4 seek=1 conv=notrunc
	dd if=head of=hd60M.img bs=512 count=1 seek=5 conv=notrunc

bootsect:bootsect.S
	$(CC)  $(CFLAGS) -I ../include/ bootsect.S -o bootsect.tmp
	$(OBJCOPY) -S -O binary -j .text bootsect.tmp  bootsect

setup:setup.S
	$(CC)  $(CFLAGS) -I ../include/ setup.S -o setup.tmp
	$(OBJCOPY) -S -O binary -j .text setup.tmp  setup

head:head.S
	$(CC)  $(CFLAGS) -I ../include/ head.S -o head.tmp
	$(OBJCOPY) -S -O binary -j .text head.tmp  head
bochs:
	bochs -f ../HLOS_bochsrc
	make clean

clean:
	rm -f bootsect.tmp bootsect setup.tmp setup head.tmp  head hd60M.img
