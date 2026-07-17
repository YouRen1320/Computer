// 两个原始输入来自命令行；转换后仍必须分别验证有效性。
const rawScore = process.argv[2] ?? "";
const rawRetryCount = process.argv[3] ?? "";
const score = Number(rawScore);
const retryCount = Number(rawRetryCount);

// score 使用精确合同；TODO：不要用 Boolean(retryCount) 拒绝合法零值。
const scoreIsValid = rawScore.trim() !== "" && Number.isInteger(score) && score >= 0 && score <= 100;
const retryIsValid = Boolean(retryCount) && retryCount <= 3;

// 非法输入必须在进入分类和循环前拒绝。
if (!scoreIsValid) {
  console.log("result=INVALID_SCORE");
  process.exitCode = 2;
} else if (!retryIsValid) {
  console.log("result=INVALID_RETRY_COUNT");
  process.exitCode = 2;
} else {
  // 范围分支完整覆盖三个教学优先级。
  let priority = "P3";
  if (score >= 80) {
    priority = "P1";
  } else if (score >= 50) {
    priority = "P2";
  } else {
    priority = "P3";
  }

  // TODO：补齐 P2 的离散队列映射，不能让 default 吞掉合法值。
  let queue = "invalid";
  switch (priority) {
    case "P1":
      queue = "emergency";
      break;
    case "P3":
      queue = "standard";
      break;
    default:
      queue = "invalid";
      break;
  }

  // 输出是练习合同；TODO：修复 <= 导致的上界偏一。
  console.log(`priority=${priority}`);
  console.log(`queue=${queue}`);
  for (let retryIndex = 0; retryIndex <= retryCount; retryIndex += 1) {
    console.log(`retry=${retryIndex + 1}`);
  }
}
