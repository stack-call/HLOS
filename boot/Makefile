include ../Makefile.header

all:bootsect setup head ../tools/hd60M.img

	cp ../tools/hd60M.img ./
	dd if=bootsect of=hd60M.img bs=512 count=1 seek=0 conv=notrunc
	dd if=setup of=hd60M.img bs=512 count=4 seek=1 conv=notrunc
	dd if=system of=hd60M.img bs=512 count=1 seek=5 conv=notrunc

bootsect:bootsect.S
	$(CC)  $(CFLAGS) -I ../include/ bootsect.S -o bootsect.tmp
	$(OBJCOPY) $(OBJCOPYFLAGS) bootsect.tmp  bootsect

setup:setup.S
	$(CC)  $(CFLAGS) -I ../include/ setup.S -o setup.tmp
	$(OBJCOPY) $(OBJCOPYFLAGS) setup.tmp  setup

head.o:head.S
	$(CC)  $(CFLAGS) -c -I ../include/ head.S -o head.o
	#$(OBJCOPY) $(OBJCOPYFLAGS) head.tmp  head

bochs:
	bochs -f ../HLOS_bochsrc
	make clean

clean:
	rm -f bootsect.tmp bootsect setup.tmp setup head.tmp  head.o head hd60M.img
