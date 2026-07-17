import { Window } from "happy-dom";

// The fixture has an id contract, while this injected query incorrectly expects a class.
const window = new Window();
window.document.write("<main><ul id='work-order-list'></ul></main>");
const list = window.document.querySelector(".work-order-list");
const selectorDrifted = list === null;
await window.happyDOM.close();
if (!selectorDrifted) {
  throw new Error("selector fault fixture did not drift");
}
console.error("DOM_SELECTION_DRIFT_MISSING_ROOT");
process.exitCode = 1;
