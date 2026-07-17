// 固定分数与次数来自教学输入，避免网络和真实工单改变控制流轨迹。
const score = 80;
const retryCount = 2;

// 阈值从高到低互斥匹配，得到单一教学优先级。
let priority = "P3";
if (score >= 80) {
  priority = "P1";
} else if (score >= 50) {
  priority = "P2";
} else {
  priority = "P3";
}

// switch 把离散优先级映射到展示队列；default 保留未知值保护。
let queue = "invalid";
switch (priority) {
  case "P1":
    queue = "emergency";
    break;
  case "P2":
    queue = "expedited";
    break;
  case "P3":
    queue = "standard";
    break;
  default:
    queue = "invalid";
    break;
}

// 这两行是分支输出合同，不是后端优先级授权。
console.log(`priority=${priority}`);
console.log(`queue=${queue}`);

// for 执行精确 retryCount 次，人类轮次从 1 开始显示。
for (let retryIndex = 0; retryIndex < retryCount; retryIndex += 1) {
  console.log(`retry=${retryIndex + 1}`);
}

// while 每轮递减 remaining，显式证明终止进度。
let remaining = retryCount;
while (remaining > 0) {
  console.log(`remaining=${remaining}`);
  remaining -= 1;
}

// 字符串迭代跳过连字符，在冒号处离开最近的 for...of。
for (const character of "P-1:IGNORED") {
  if (character === "-") {
    continue;
  }
  if (character === ":") {
    break;
  }
  console.log(`code=${character}`);
}
