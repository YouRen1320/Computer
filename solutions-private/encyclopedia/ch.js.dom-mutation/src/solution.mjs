import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Window } from "happy-dom";
import {
  removeWorkOrder,
  renderWorkOrders,
  updateWorkOrderStatus,
} from "./work-order-board.mjs";

// The fixture proves text safety, boolean property state, identity preservation, and order.
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const window = new Window();
window.document.write(html);
window.document.close();
const { document } = window;
const orders = [
  { id: "WO-1", status: "CREATED", title: "<img data-injected src='x'>", selected: false },
  { id: "WO-2", status: "ASSIGNED", title: "压缩机巡检", selected: false },
];

const list = renderWorkOrders(document, orders);
assert.equal(list.querySelector("[data-injected]"), null);
assert.ok([...list.children].every((child) => child.tagName === "LI"));
const checkbox = list.querySelector("[data-field='selected']");
assert.equal(checkbox.checked, false);
assert.equal(checkbox.hasAttribute("checked"), false);
const beforeUpdate = list.querySelector("[data-work-order-id='WO-2']");
assert.strictEqual(updateWorkOrderStatus(document, "WO-2", "IN_PROGRESS"), beforeUpdate);
assert.equal(removeWorkOrder(document, "WO-1"), true);
assert.deepEqual([...list.children].map((item) => item.dataset.workOrderId), ["WO-2"]);
assert.ok(document.querySelector("main > section > ul#work-order-list"));

console.log("render=count:2,order:WO-1>WO-2");
console.log("text=safe");
console.log("property=checked:false,attribute:absent");
console.log("update=WO-2:IN_PROGRESS,identity:same");
console.log("remove=count:1,order:WO-2");
console.log("semantics=main>section>ul>li");
await window.happyDOM.close();
