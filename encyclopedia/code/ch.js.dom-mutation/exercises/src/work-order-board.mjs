// renderWorkOrders intentionally contains three mapping faults that learners repair in sequence.
export function renderWorkOrders(document, workOrders) {
  // TODO 1: align this selector with the known HTML id contract.
  const list = document.querySelector(".work-order-list");
  if (!list) {
    throw new Error("DOM_SELECTION_DRIFT_EXERCISE");
  }

  // TODO 2/3/4: replace HTML interpolation, div children, and string boolean attributes with explicit nodes/properties.
  list.innerHTML = workOrders
    .map((workOrder) => `<div data-work-order-id="${workOrder.id}" data-status="${workOrder.status}">
      <h3>${workOrder.title}</h3>
      <p data-field="status">状态：${workOrder.status}</p>
      <input type="checkbox" data-field="selected" checked="${workOrder.selected}">
    </div>`)
    .join("");
  return list;
}

// findItem compares dataset identity without interpreting work-order IDs as CSS syntax.
function findItem(list, id) {
  return [...list.querySelectorAll("[data-work-order-id]")]
    .find((item) => item.dataset.workOrderId === id);
}

// updateWorkOrderStatus is already minimal and must keep the existing item identity.
export function updateWorkOrderStatus(document, id, nextStatus) {
  const list = document.querySelector("#work-order-list");
  const item = findItem(list, id);
  if (!item) throw new Error(`work order item not found: ${id}`);
  item.dataset.status = nextStatus;
  item.querySelector("[data-field='status']").textContent = `状态：${nextStatus}`;
  return item;
}

// removeWorkOrder removes only the matching business item and reports absence.
export function removeWorkOrder(document, id) {
  const list = document.querySelector("#work-order-list");
  const item = findItem(list, id);
  if (!item) return false;
  item.remove();
  return true;
}
