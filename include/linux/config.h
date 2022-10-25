#ifndef _CONFIG_H
#define _CONFIG_H

#define DEF_INITSEG	0x9000	                  /* 引导扇区程序将被移动到的段值	*/
#define DEF_SYSSEG	0x1000	                  /* 引导扇区程序把系统模块加载到内存的段值.	*/
#define DEF_SETUPSEG	0x9020	              /* setup程序所处内存段位置.	*/
#define DEF_SYSSIZE	0x3000	                  /* 内核系统模块默认最大节数(16字节=1节)	*/

#endif
