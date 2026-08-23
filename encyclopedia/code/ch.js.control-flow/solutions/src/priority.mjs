// 两个命令行文本是练习数据源，先显式转换再进入控制流。
const rawScore = process.argv[2] ?? "";
const rawRetryCount = process.argv[3] ?? "";
const score = Number(rawScore);
const retryCount = Number(rawRetryCount);

// 有效性由整数与范围合同决定，合法零值不会被 truthiness 拒绝。
const scoreIsValid = rawScore.trim() !== "" && Number.isInteger(score) && score >= 0 && score <= 100;
const retryIsValid = rawRetryCount.trim() !== "" && Number.isInteger(retryCount) && retryCount >= 0 && retryCount <= 3;

// 非法输入产生稳定结果和退出码，不进入后续分类或循环。
if (!scoreIsValid) {
  console.log("result=INVALID_SCORE");
  process.exitCode = 2;
} else if (!retryIsValid) {
  console.log("result=INVALID_RETRY_COUNT");
  process.exitCode = 2;
} else {
  // 阈值从高到低互斥覆盖全部有效分数。
  let priority = "P3";
  if (score >= 80) {
    priority = "P1";
  } else if (score >= 50) {
    priority = "P2";
  } else {
    priority = "P3";
  }

  // switch 完整映射离散优先级，default 保留未知值保护。
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

  // stdout 固定分支结果和精确 retryCount 次循环副作用。
  console.log(`priority=${priority}`);
  console.log(`queue=${queue}`);
  for (let retryIndex = 0; retryIndex < retryCount; retryIndex += 1) {
    console.log(`retry=${retryIndex + 1}`);
  }
}
