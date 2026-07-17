// requireElement converts selector drift into an immediate responsibility-specific failure.
function requireElement(root, selector) {
  const element = root.querySelector(selector);
  if (!element) {
    throw new Error(`required DOM root is missing: ${selector}`);
  }
  return element;
}

// findWorkOrderItem compares dataset identity without interpolating untrusted IDs into CSS syntax.
function findWorkOrderItem(list, id) {
  return [...list.querySelectorAll("[data-work-order-id]")]
    .find((item) => item.dataset.workOrderId === id);
}

// createWorkOrderItem maps structured data to fixed semantic elements and writes user-facing values as text.
function createWorkOrderItem(document, workOrder) {
  const item = document.createElement("li");
  item.dataset.workOrderId = workOrder.id;
  item.dataset.status = workOrder.status;
  const article = document.createElement("article");
  const heading = document.createElement("h3");
  heading.textContent = workOrder.title;
  const status = document.createElement("p");
  status.dataset.field = "status";
  status.textContent = `状态：${workOrder.status}`;
  const selectedLabel = document.createElement("label");
  const selected = document.createElement("input");
  selected.type = "checkbox";
  selected.disabled = true;
  // checked is current boolean state; the code intentionally avoids a misleading checked attribute.
  selected.checked = workOrder.selected === true;
  selected.dataset.field = "selected";
  selectedLabel.append(selected, document.createTextNode(" 已选择"));
  article.append(heading, status, selectedLabel);
  item.append(article);
  return item;
}

// renderWorkOrders owns only list children and empty-state text, preserving surrounding landmarks.
export function renderWorkOrders(document, workOrders) {
  const list = requireElement(document, "#work-order-list");
  const boardStatus = requireElement(document, "#board-status");
  const fragment = document.createDocumentFragment();
  for (const workOrder of workOrders) {
    fragment.append(createWorkOrderItem(document, workOrder));
  }
  list.replaceChildren(fragment);
  boardStatus.hidden = workOrders.length !== 0;
  boardStatus.textContent = workOrders.length === 0 ? "暂无工单。" : "";
  return list;
}

// updateWorkOrderStatus performs the minimum two-field mutation while preserving target li identity.
export function updateWorkOrderStatus(document, id, nextStatus) {
  const list = requireElement(document, "#work-order-list");
  const item = findWorkOrderItem(list, id);
  if (!item) {
    throw new Error(`work order item not found: ${id}`);
  }
  item.dataset.status = nextStatus;
  requireElement(item, "[data-field='status']").textContent = `状态：${nextStatus}`;
  return item;
}

// removeWorkOrder removes only the matching li and reports whether a node existed.
export function removeWorkOrder(document, id) {
  const list = requireElement(document, "#work-order-list");
  const item = findWorkOrderItem(list, id);
  if (!item) return false;
  item.remove();
  return true;
}
