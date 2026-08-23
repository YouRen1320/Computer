// TODO：工单号来自固定练习输入，声明方式应表达本次追踪中不可重赋值。
let workOrderId = "WO-1001";

// TODO：currentStatus 是有意变化的快照，声明方式必须允许后续赋值。
const currentStatus = "CREATED";

// stdout 合同要求先打印工单与旧状态，再在赋值后打印新状态。
console.log(`workOrder=${workOrderId}`);
console.log(`before=${currentStatus}`);

// TODO：当前观察点放早了；移动语句而不是修改 expected.stdout。
console.log(`after=${currentStatus}`);
currentStatus = "ASSIGNED";
