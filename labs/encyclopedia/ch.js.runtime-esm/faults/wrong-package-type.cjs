// 这个明确的 CommonJS 文件故意使用静态 ESM import，用于稳定触发包格式解析失败。
import { statusCode } from "../src/status-label.mjs";

// 若错误未被触发，这个副作用会暴露错误注入失效。
console.log(`unexpected=${statusCode}`);
