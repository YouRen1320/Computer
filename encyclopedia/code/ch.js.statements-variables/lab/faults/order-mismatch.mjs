// 状态在输出之后才更新，用于证明观察点读取的是赋值前快照。
let currentStatus = "CREATED";

// 这个输出应是 CREATED；故意错误的预言会声称它已经是 ASSIGNED。
console.log(`observed=${currentStatus}`);
currentStatus = "ASSIGNED";
