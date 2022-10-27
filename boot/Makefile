include ../Makefile.header

all:bootsect setup ../tools/hd60M.img clean
	make clean
	cp ../tools/hd60M.img ./
	dd if=bootsect of=hd60M.img bs=512 count=1 seek=0 conv=notrunc
	dd if=setup of=hd60M.img bs=512 count=4 seek=1 conv=notrunc

bootsect:bootsect.S
	$(CC)  $(CFLAGS) -I ../include/ bootsect.S -o bootsect.tmp
	$(OBJCOPY) -S -O binary -j .text $(BUILD)bootsect.tmp  bootsect

setup:setup.S
	$(CC)  $(CFLAGS) -I ../include/ setup.S -o setup.tmp
	$(OBJCOPY) -S -O binary -j .text $(BUILD)setup.tmp  setup

bochs:
	bochs -f ../HLOS_bochsrc

clean:
	rm -f bootsect.tmp bootsect setup.tmp setup hd60M.img
