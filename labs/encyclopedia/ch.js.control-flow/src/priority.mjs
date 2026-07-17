// 两个原始值来自 Node 命令行，进入条件前必须显式转换并验证。
const rawScore = process.argv[2] ?? "";
const rawRetryCount = process.argv[3] ?? "";
const score = Number(rawScore);
const retryCount = Number(rawRetryCount);

// 空文本、非整数和越界值分别由精确布尔表达式拒绝，不依赖 truthiness。
const scoreIsValid = rawScore.trim() !== "" && Number.isInteger(score) && score >= 0 && score <= 100;
const retryIsValid = rawRetryCount.trim() !== "" && Number.isInteger(retryCount) && retryCount >= 0 && retryCount <= 3;

// 非法输入与有效分类互斥；exitCode=2 是可预期输入拒绝的宿主证据。
if (!scoreIsValid) {
  console.log("result=INVALID_SCORE");
  process.exitCode = 2;
} else if (!retryIsValid) {
  console.log("result=INVALID_RETRY_COUNT");
  process.exitCode = 2;
} else {
  // 阈值按高到低排列，使每个 0..100 分数只命中一个优先级。
  let priority = "P3";
  if (score >= 80) {
    priority = "P1";
  } else if (score >= 50) {
    priority = "P2";
  } else {
    priority = "P3";
  }

  // switch 完整映射三个离散优先级，并保留不可达值的防御性 default。
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

  // 分支结果先输出，后续循环精确执行 retryCount 次。
  console.log(`priority=${priority}`);
  console.log(`queue=${queue}`);
  for (let retryIndex = 0; retryIndex < retryCount; retryIndex += 1) {
    console.log(`retry=${retryIndex + 1}`);
  }
}
