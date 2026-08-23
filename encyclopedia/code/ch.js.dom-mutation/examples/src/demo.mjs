import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Window } from "happy-dom";
import {
  removeWorkOrder,
  renderWorkOrders,
  updateWorkOrderStatus,
} from "./work-order-board.mjs";

// The HTML file is the sole structure source; happy-dom parses it into an isolated document.
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const window = new Window({ url: "https://factorycare.example/" });
window.document.write(html);
window.document.close();
const { document } = window;

// The fixture includes markup-looking text to prove it never reaches the HTML parser.
const workOrders = [
  { id: "WO-1", status: "CREATED", title: "泵站 <img data-injected>", selected: true },
  { id: "WO-2", status: "ASSIGNED", title: "压缩机巡检", selected: false },
  { id: "WO-3", status: "CREATED", title: "传感器校准", selected: false },
];

const list = renderWorkOrders(document, workOrders);
assert.equal(list.children.length, 3);
assert.deepEqual([...list.children].map((item) => item.dataset.workOrderId), [
  "WO-1", "WO-2", "WO-3",
]);
assert.equal(list.querySelector("[data-injected]"), null);
assert.match(list.querySelector("h3").textContent, /<img data-injected>/u);
assert.ok([...list.children].every((item) => item.tagName === "LI"));

const selected = list.querySelector("[data-work-order-id='WO-1'] [data-field='selected']");
assert.equal(selected.checked, true);
assert.equal(selected.hasAttribute("checked"), false);

const beforeUpdate = list.querySelector("[data-work-order-id='WO-2']");
const updated = updateWorkOrderStatus(document, "WO-2", "IN_PROGRESS");
assert.strictEqual(updated, beforeUpdate);
assert.equal(updated.dataset.status, "IN_PROGRESS");
assert.equal(updated.querySelector("[data-field='status']").textContent, "状态：IN_PROGRESS");
assert.equal(removeWorkOrder(document, "WO-1"), true);
assert.equal(removeWorkOrder(document, "missing"), false);
assert.deepEqual([...list.children].map((item) => item.dataset.workOrderId), ["WO-2", "WO-3"]);
assert.ok(document.querySelector("main > section > ul#work-order-list"));

console.log("environment=happy-dom-17.6.3");
console.log("initial=count:3,order:WO-1>WO-2>WO-3");
console.log("text-safe=true");
console.log("selected-property=true,checked-attribute=false");
console.log("update=WO-2:IN_PROGRESS,identity:preserved");
console.log("remove=count:2,order:WO-2>WO-3");
console.log("semantics=main>section>ul>li");
await window.happyDOM.close();
