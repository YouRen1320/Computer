// 入口通过完整相对说明符读取依赖模块的真实命名导出。
import { statusLabel } from "./status-label.js";

// stdout 是与公开练习共享的最小预言，不包含环境相关信息。
console.log("status=ASSIGNED");
console.log(`label=${statusLabel}`);
