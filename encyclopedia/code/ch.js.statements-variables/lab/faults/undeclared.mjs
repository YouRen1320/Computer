// 声明使用 workOrderId，但下一行故意改变大小写以制造未声明标识符。
const workOrderId = "WO-1001";

// 正确诊断应指向 workorderId，而不是修改已正确声明的数据源。
console.log(`workOrder=${workorderId}`);
