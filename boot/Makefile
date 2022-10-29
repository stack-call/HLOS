include ../Makefile.header

CFLAGS += -I ../include

all:bootsect setup head.o

bootsect:bootsect.S
	$(CC)  $(CFLAGS) bootsect.S -o bootsect.tmp
	$(OBJCOPY) $(OBJCOPYFLAGS) bootsect.tmp  bootsect

setup:setup.S
	$(CC)  $(CFLAGS) setup.S -o setup.tmp
	$(OBJCOPY) $(OBJCOPYFLAGS) setup.tmp  setup

head.o:head.S
	$(CC)  $(CFLAGS) -c head.S -o head.o
	#$(OBJCOPY) $(OBJCOPYFLAGS) head.tmp  head

bochs:
	bochs -f ../HLOS_bochsrc
	make clean

clean:
	rm -f bootsect.tmp bootsect setup.tmp setup head.tmp  head.o head hd60M.img
