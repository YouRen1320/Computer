// Node ESM 相对导入故意省略扩展名，用于触发链接阶段的模块未找到证据。
import { statusCode } from "../src/status-label";

// 正确故障应在模块链接时发生，因此这一输出不应出现。
console.log(`unexpected=${statusCode}`);
