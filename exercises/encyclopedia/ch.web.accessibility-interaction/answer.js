// Responsibility: starter 尝试处理键盘、展开、错误与删除，等待学习者修复。
// Data source: 使用固定教学 DOM 与伪造 fieldErrors，不读取生产数据。
// Mapping: starter 故意把服务器 field 直接拼进 selector，展示不可信映射故障。
// Side effects: 拦截 Tab、写入 HTML、删除节点且不恢复焦点，均为待诊断故障。
document.addEventListener("keydown", (event) => {
  if (event.key === "Tab") {
    event.preventDefault();
    document.getElementById("description").focus();
  }
});

document.getElementById("toggle").addEventListener("click", () => {
  document.getElementById("panel").hidden = false;
});

function showErrors(problem) {
  for (const fieldError of problem.fieldErrors) {
    const control = document.querySelector(`#${fieldError.field}`);
    if (control) control.innerHTML = fieldError.message;
  }
}

document.getElementById("remove").addEventListener("click", () => {
  document.getElementById("attachment").remove();
});
