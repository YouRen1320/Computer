// 固定工单号与初始状态来自可重复的实验输入，不访问真实数据库。
const workOrderId = "WO-1001";
let currentStatus = "CREATED";

// 输出顺序构成绿色基线，赋值前后状态必须分别可观察。
console.log(`workOrder=${workOrderId}`);
console.log(`before=${currentStatus}`);
currentStatus = "ASSIGNED";
console.log(`after=${currentStatus}`);
