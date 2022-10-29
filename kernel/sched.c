#include <linux/sched.h>

// 定义用户堆栈,共1K项,容量4K字节.在内核初始化操作过程中被用作内核栈,初始化完成以后将被用作任务0的用户堆栈.在运行任务0之前它是内核栈,
// 以后用作任务0和1的用户态栈.
// 下面结构用于设置堆栈ss:esp(数据段选择符,指针).
// ss被设置为内核数据段选择符(0x10),指针esp指在user_stack数组最后一项后面.这是因为Interl CPU执行堆栈操作时是先递减堆栈指针sp值,
// 然后在sp指针处保存入栈内容.
__attribute__((__aligned__(PAGE_SIZE)))
long user_stack [PAGE_SIZE >> 2] ;
//加上对其之前esp是0x0000201f，加上之后esp是0x00002fff
struct {
	long * a;
	short b;
	} stack_start = { &user_stack [PAGE_SIZE >> 2], 0x10 };
