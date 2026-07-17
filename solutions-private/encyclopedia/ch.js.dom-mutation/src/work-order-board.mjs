// requireList makes the stable HTML selector contract fail at its first boundary.
function requireList(document) {
  const list = document.querySelector("#work-order-list");
  if (!list) throw new Error("required DOM root is missing: #work-order-list");
  return list;
}

// findItem compares dataset identity and avoids dynamic selector interpolation.
function findItem(list, id) {
  return [...list.querySelectorAll("[data-work-order-id]")]
    .find((item) => item.dataset.workOrderId === id);
}

// createItem maps data into semantic elements and treats every display field as text/current property.
function createItem(document, workOrder) {
  const item = document.createElement("li");
  item.dataset.workOrderId = workOrder.id;
  item.dataset.status = workOrder.status;
  const article = document.createElement("article");
  const heading = document.createElement("h3");
  heading.textContent = workOrder.title;
  const status = document.createElement("p");
  status.dataset.field = "status";
  status.textContent = `状态：${workOrder.status}`;
  const selected = document.createElement("input");
  selected.type = "checkbox";
  selected.disabled = true;
  selected.dataset.field = "selected";
  selected.checked = workOrder.selected === true;
  article.append(heading, status, selected);
  item.append(article);
  return item;
}

// renderWorkOrders replaces only list children with a fragment built from caller data.
export function renderWorkOrders(document, workOrders) {
  const list = requireList(document);
  const fragment = document.createDocumentFragment();
  for (const workOrder of workOrders) fragment.append(createItem(document, workOrder));
  list.replaceChildren(fragment);
  return list;
}

// updateWorkOrderStatus preserves item identity and synchronizes dataset plus visible status text.
export function updateWorkOrderStatus(document, id, nextStatus) {
  const list = requireList(document);
  const item = findItem(list, id);
  if (!item) throw new Error(`work order item not found: ${id}`);
  item.dataset.status = nextStatus;
  item.querySelector("[data-field='status']").textContent = `状态：${nextStatus}`;
  return item;
}

// removeWorkOrder performs one targeted removal and reports whether an item existed.
export function removeWorkOrder(document, id) {
  const list = requireList(document);
  const item = findItem(list, id);
  if (!item) return false;
  item.remove();
  return true;
}
