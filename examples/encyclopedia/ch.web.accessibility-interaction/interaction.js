// Responsibility: 同步说明展开状态，并把一次教学 Problem 映射为摘要、字段状态和焦点。
// Data source: 只读取同目录 problem.json；未知 field 不拼接选择器，而进入全局摘要。
// Mapping: API field 通过固定 allowlist 对应 control/error id，文本只通过 textContent 输出。
// Side effects: 拦截教学提交、读取本地 JSON、更新 DOM/ARIA，并在失败后聚焦错误摘要。
const fieldMap = Object.freeze({
  assetId: Object.freeze({ controlId: "asset-id", errorId: "asset-id-error" }),
  description: Object.freeze({ controlId: "description", errorId: "description-error" })
});

const toggle = document.getElementById("instructions-toggle");
const panel = document.getElementById("instructions-panel");
const form = document.getElementById("report-form");
const summary = document.getElementById("error-summary");
const status = document.getElementById("submit-status");

toggle.addEventListener("click", () => {
  const willOpen = panel.hidden;
  panel.hidden = !willOpen;
  toggle.setAttribute("aria-expanded", String(willOpen));
  toggle.textContent = willOpen ? "隐藏填写说明" : "显示填写说明";
});

function clearErrors() {
  summary.hidden = true;
  summary.querySelector("ul").replaceChildren();
  for (const mapping of Object.values(fieldMap)) {
    document.getElementById(mapping.controlId).removeAttribute("aria-invalid");
    const error = document.getElementById(mapping.errorId);
    error.hidden = true;
    error.textContent = "";
  }
}

function showProblem(problem) {
  const list = summary.querySelector("ul");
  let count = 0;

  for (const fieldError of problem.fieldErrors ?? []) {
    const mapping = fieldMap[fieldError.field];
    const item = document.createElement("li");
    if (mapping) {
      const control = document.getElementById(mapping.controlId);
      const error = document.getElementById(mapping.errorId);
      control.setAttribute("aria-invalid", "true");
      error.textContent = fieldError.message;
      error.hidden = false;

      const link = document.createElement("a");
      link.href = `#${mapping.controlId}`;
      link.textContent = fieldError.message;
      item.append(link);
    } else {
      item.textContent = fieldError.message;
    }
    list.append(item);
    count += 1;
  }

  summary.hidden = false;
  status.textContent = `提交失败，有 ${count} 处需要修正。`;
  summary.focus();
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  clearErrors();
  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }

  status.textContent = "正在验证教学请求。";
  try {
    const response = await fetch("./problem.json");
    showProblem(await response.json());
  } catch (_error) {
    status.textContent = "无法读取教学错误夹具，请稍后重试。";
  }
});
