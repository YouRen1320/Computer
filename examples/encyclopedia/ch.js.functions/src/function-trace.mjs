// 纯分类函数只根据已验证分数返回教学优先级，不产生外部副作用。
function classifyPriority(score) {
  if (score >= 80) {
    return "P1";
  }
  if (score >= 50) {
    return "P2";
  }
  return "P3";
}

// 函数表达式合计分钟；缺失 reviewMinutes 时明确默认 0。
const totalMinutes = function (activeMinutes, reviewMinutes = 0) {
  return activeMinutes + reviewMinutes;
};

// 剩余参数收集同质分钟值，本例只借用 for...of 进行累加。
function sumMinutes(...minutes) {
  let total = 0;
  for (const minute of minutes) {
    total += minute;
  }
  return total;
}

// 箭头函数是无副作用的文本格式化器，可作为函数值传入回调入口。
const formatPriority = (priority) => `priority=${priority}`;

// 回调入口同步调用 formatter 恰好一次，并把回调结果返回给调用方。
function applyFormatter(value, formatter) {
  return formatter(value);
}

let callbackCallCount = 0;
const tracedFormatter = (priority) => {
  // 计数是示例验证外壳的显式副作用，用于证明回调恰好调用一次。
  callbackCallCount += 1;
  return formatPriority(priority);
};

// stdout 固定每个函数返回值和调用次数，形成可逐字比较的调用轨迹。
console.log(`classify80=${classifyPriority(80)}`);
console.log(`classify50=${classifyPriority(50)}`);
console.log(`defaultTotal=${totalMinutes(35)}`);
console.log(`sum=${sumMinutes(5, 10, 27)}`);
console.log(`formatted=${applyFormatter("P1", tracedFormatter)}`);
console.log(`callbackCalls=${callbackCallCount}`);
