// Responsibility: 同步帮助展开、模拟字段错误并为删除当前附件提供稳定焦点恢复。
// Data source: 只使用 a11y-lab-v1 固定 DOM 与本地错误文字。
// Mapping: expanded 镜像 panel.hidden；description 错误映射固定 id；删除后恢复到附件标题。
// Side effects: 更新 DOM/ARIA/焦点并删除虚构附件项，不发网络请求。
const toggle = document.getElementById("toggle");
const panel = document.getElementById("help-panel");
const form = document.getElementById("report-form");
const summary = document.getElementById("error-summary");
const description = document.getElementById("description");
const descriptionError = document.getElementById("description-error");

toggle.addEventListener("click", () => {
  const open = panel.hidden;
  panel.hidden = !open;
  toggle.setAttribute("aria-expanded", String(open));
  toggle.textContent = open ? "隐藏帮助" : "显示帮助";
});

form.addEventListener("submit", (event) => {
  event.preventDefault();
  if (description.value.trim().length >= 10) return;
  description.setAttribute("aria-invalid", "true");
  descriptionError.textContent = "故障描述至少需要 10 个字符。";
  descriptionError.hidden = false;
  summary.querySelector("ul").replaceChildren();
  const item = document.createElement("li");
  item.textContent = "故障描述至少需要 10 个字符。";
  summary.querySelector("ul").append(item);
  summary.hidden = false;
  summary.focus();
});

document.getElementById("remove-attachment").addEventListener("click", () => {
  document.getElementById("attachment-demo").remove();
  document.getElementById("attachments-heading").focus();
  document.getElementById("status").textContent = "已从教学列表移除附件 demo.png。";
});
