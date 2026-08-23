// TODO：补全相对说明符扩展名，并把导入名改为依赖模块真实公开的 statusLabel。
import { statusText } from "./status-label";

// 此 stdout 格式是练习合同；修复模块连接，不要修改预言来隐藏错误。
console.log("status=ASSIGNED");
console.log(`label=${statusText}`);
