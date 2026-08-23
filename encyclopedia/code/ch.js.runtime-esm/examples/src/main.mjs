// 入口使用带扩展名的相对说明符，明确连接本地 ESM 导出合同。
import { statusCode, statusLabel } from "./status-label.mjs";

// 这两行 stdout 是示例唯一外部副作用，格式由 expected.stdout 固定。
console.log(`status=${statusCode}`);
console.log(`label=${statusLabel}`);
