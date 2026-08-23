import assert from "node:assert/strict";
import { Window } from "happy-dom";

// createDocument is the isolated simulator data source and preserves one semantic shell per run.
function createDocument() {
  const window = new Window({ url: "https://factorycare.example/" });
  window.document.write(`<!doctype html>
    <html lang="zh-CN"><body><main><h1>工单队列</h1>
      <section aria-labelledby="queue-title"><h2 id="queue-title">待处理工单</h2>
        <p id="board-status" aria-live="polite"></p>
        <ul id="work-order-list"></ul>
      </section></main></body></html>`);
  window.document.close();
  return window;
}

// requireElement exposes selector drift before an unrelated null-property error.
function requireElement(root, selector) {
  const element = root.querySelector(selector);
  assert.ok(element, `required DOM root is missing: ${selector}`);
  return element;
}

// findItem compares dataset values directly so fixture IDs never become selector syntax.
function findItem(list, id) {
  return [...list.querySelectorAll("[data-work-order-id]")]
    .find((item) => item.dataset.workOrderId === id);
}

// createItem maps each record to li/article/h3/p plus a disabled current-state checkbox.
function createItem(document, order) {
  const item = document.createElement("li");
  item.dataset.workOrderId = order.id;
  item.dataset.status = order.status;
  const article = document.createElement("article");
  const heading = document.createElement("h3");
  heading.textContent = order.title;
  const status = document.createElement("p");
  status.dataset.field = "status";
  status.textContent = `状态：${order.status}`;
  const selected = document.createElement("input");
  selected.type = "checkbox";
  selected.disabled = true;
  selected.checked = order.selected === true;
  selected.dataset.field = "selected";
  article.append(heading, status, selected);
  item.append(article);
  return item;
}

// render replaces only list children and keeps main/section landmarks intact.
function render(document, orders) {
  const list = requireElement(document, "#work-order-list");
  const fragment = document.createDocumentFragment();
  for (const order of orders) fragment.append(createItem(document, order));
  list.replaceChildren(fragment);
  const status = requireElement(document, "#board-status");
  status.hidden = orders.length !== 0;
  status.textContent = orders.length === 0 ? "暂无工单。" : "";
  return list;
}

// update changes only the status representations and returns the preserved item identity.
function update(document, id, nextStatus) {
  const list = requireElement(document, "#work-order-list");
  const item = findItem(list, id);
  assert.ok(item, `work order item not found: ${id}`);
  item.dataset.status = nextStatus;
  requireElement(item, "[data-field='status']").textContent = `状态：${nextStatus}`;
  return item;
}

// remove reports absence instead of throwing so repeated deletion has an explicit oracle.
function remove(document, id) {
  const list = requireElement(document, "#work-order-list");
  const item = findItem(list, id);
  if (!item) return false;
  item.remove();
  return true;
}

const window = createDocument();
const { document } = window;
const emptyList = render(document, []);
assert.equal(emptyList.children.length, 0);
assert.equal(requireElement(document, "#board-status").hidden, false);

const orders = [
  { id: "WO-1", status: "CREATED", title: "<img data-injected>", selected: true },
  { id: "WO-2", status: "ASSIGNED", title: "压缩机巡检", selected: false },
  { id: "WO-3", status: "CREATED", title: "传感器校准", selected: false },
];
const list = render(document, orders);
assert.equal(list.querySelector("[data-injected]"), null);
assert.ok([...list.children].every((item) => item.tagName === "LI"));
const selected = requireElement(list, "[data-work-order-id='WO-1'] [data-field='selected']");
assert.equal(selected.checked, true);
assert.equal(selected.hasAttribute("checked"), false);
const beforeUpdate = requireElement(list, "[data-work-order-id='WO-2']");
assert.strictEqual(update(document, "WO-2", "IN_PROGRESS"), beforeUpdate);
assert.equal(beforeUpdate.dataset.status, "IN_PROGRESS");
assert.equal(remove(document, "WO-1"), true);
assert.equal(remove(document, "WO-1"), false);
assert.deepEqual([...list.children].map((item) => item.dataset.workOrderId), ["WO-2", "WO-3"]);
assert.ok(document.querySelector("main > section > ul#work-order-list"));

console.log("S0=count:0,empty:visible");
console.log("S1=count:3,order:WO-1>WO-2>WO-3,text:safe");
console.log("S2=count:3,WO-2:IN_PROGRESS,identity:same");
console.log("S3=count:2,order:WO-2>WO-3");
console.log("structure=main>section>ul>li");
console.log("property=checked:true,attribute:absent");
await window.happyDOM.close();
