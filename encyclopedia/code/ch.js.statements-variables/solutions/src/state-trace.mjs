// 工单号来自固定练习输入，本次追踪不会切换工单，因此使用 const。
const workOrderId = "WO-1001";

// currentStatus 保存线性状态快照，后续一次赋值是题目要求的状态变化。
let currentStatus = "CREATED";

// 输出顺序构成公开练习的合同；after 必须观察赋值后的值。
console.log(`workOrder=${workOrderId}`);
console.log(`before=${currentStatus}`);
currentStatus = "ASSIGNED";
console.log(`after=${currentStatus}`);
