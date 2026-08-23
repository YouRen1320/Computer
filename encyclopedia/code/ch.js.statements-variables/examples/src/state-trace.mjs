// 固定工单号来自教学输入；真实身份与状态由 FactoryCare 后端保存。
const workOrderId = "WO-1001";

// currentStatus 是线性追踪中的可变快照，先保存创建状态。
let currentStatus = "CREATED";

// 这些输出是示例的外部预言，先观察旧值，再执行唯一一次赋值。
console.log(`workOrder=${workOrderId}`);
console.log(`before=${currentStatus}`);
currentStatus = "ASSIGNED";
console.log(`after=${currentStatus}`);
