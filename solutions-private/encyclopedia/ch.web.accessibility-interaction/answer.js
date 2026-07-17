// Responsibility: 同步帮助状态，安全映射字段错误，并在删除当前附件后恢复焦点。
// Data source: 只处理受控教学 Problem 形状；未知 field 进入摘要。
// Mapping: 固定 fieldMap 连接 API field 和 DOM id；open 同步 hidden/expanded。
// Side effects: 更新 DOM/ARIA/焦点并删除虚构附件项，不发网络请求。
const fieldMap = Object.freeze({ description: "description" });
const toggle = document.getElementById("toggle");
const panel = document.getElementById("panel");
const summary = document.getElementById("error-summary");

toggle.addEventListener("click", () => {
  const open = panel.hidden;
  panel.hidden = !open;
  toggle.setAttribute("aria-expanded", String(open));
  toggle.textContent = open ? "隐藏帮助" : "显示帮助";
});

function showErrors(problem) {
  const list = summary.querySelector("ul");
  list.replaceChildren();
  for (const fieldError of problem.fieldErrors ?? []) {
    const id = fieldMap[fieldError.field];
    const item = document.createElement("li");
    item.textContent = fieldError.message;
    list.append(item);
    if (id) document.getElementById(id).setAttribute("aria-invalid", "true");
  }
  summary.hidden = false;
  summary.focus();
}

document.getElementById("remove").addEventListener("click", () => {
  document.getElementById("attachment").remove();
  document.getElementById("attachments-heading").focus();
  document.getElementById("status").textContent = "已移除附件 demo.png。";
});
