// 工单号按实验合同应稳定，因此用 const 建模。
const workOrderId = "WO-1001";

// 这次重赋值是受控故障；不能用改成 let 来掩盖身份漂移。
workOrderId = "WO-1002";
console.log(`unexpected=${workOrderId}`);
