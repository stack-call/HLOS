all:
test:
	cp ../tools/hd60M.img ./
	nasm test.asm -f bin -o test.bin
	nasm test1.asm -f bin -o test1.bin
	dd if=test.bin of=hd60M.img bs=512 count=1 conv=notrunc
	dd if=test1.bin of=hd60M.img bs=512 count=1 seek=1 conv=notrunc
	
bochs:
	bochs -f ../HLOS_bochsrc
	rm hd60M.img test.bin test1.bin