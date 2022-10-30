# HLOS
He‘s Linux Like Operating System

从大一到现在学操作系统也有一段时间了，但是很多细节都没有真切的感受过，因此想要动手实现一下才能真正的掌握，因此准备动手写一下。    
目标：  
* 从基础的一些功能框架开始，例如中断，进程调用，文件系统等，都会现从最简单的开始。
* 为了将来的功能添加，需要预留接口层，例如文件系统需要在对各种文件格式与文件系统之间设置一个接口层，支持兼容于便于扩充功能。
* 将来会支持多核，各种进程间传递信息的方式，还有网络模块等功能。
* 与Linux系统调用兼容，在向上的接口层与Linux兼容。
* 由于本人能力有限，因此会从一些较简单的功能开始实现，增加功能。
* 不支持软盘(没必要学习，还要写驱动)。

开发日志：  
2022-10-22 立项  
2022-10-23 [[配置bochs开发环境]](./docs/2022-10-23-bochs.md) | [[探索启动时的实模式]](./docs/2022-10-23-real_mode.md)  
2022-10-23 [[加载操作系统内核]](docs/2022-10-24-load_kernel.md)  
2022-10-25 [[加载操作系统内核]](docs/2022-10-24-load_kernel.md)  
2022-10-26 [[加载操作系统内核]](docs/2022-10-24-load_kernel.md) PS:加载内核比想象中的困难  
2022-10-29 [[加载操作系统内核并进入保护模式]](docs/2022-10-24-load_kernel.md) PS:写了几天，终于大体完成了,基本的内核代码加载功能并进入保护模式，剩下的功能在使用时完善 | [[完善启动引导程序并打开分页进入C程序]](docs/2022-10-29-enterC.md)
2022-10-30 [[完善启动引导程序并打开分页进入C程序]](docs/2022-10-29-enterC.md)


一些问题:
* git不能传输大文件，因此hd60M.img文件不能传输，因此需要在Makefile命令中使用命令创建并在运行结束后删除(或者在git时删除)
设计架构：

设计架构：