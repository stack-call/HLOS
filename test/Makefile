all:
testcall:
	cp ../tools/hd60M.img ./
	nasm testcall.asm -f bin -o testcall.bin
	nasm testcall1.asm -f bin -o testcall1.bin
	dd if=testcall.bin of=hd60M.img bs=512 count=1 conv=notrunc
	dd if=testcall1.bin of=hd60M.img bs=512 count=1 seek=1 conv=notrunc

testhard:
	cp ../tools/hd60M.img ./
	nasm testhard.asm -f bin -o testhard.bin
	nasm testhard1.asm -f bin -o testhard1.bin
	dd if=testhard.bin of=hd60M.img bs=512 count=1 conv=notrunc
	dd if=testhard1.bin of=hd60M.img bs=512 count=1 seek=1 conv=notrunc
bochs:
	bochs -f ../HLOS_bochsrc
	rm hd60M.img *.bin