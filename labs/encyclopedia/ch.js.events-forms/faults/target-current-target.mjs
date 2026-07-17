import { Window } from "happy-dom";

// This fault reads business identity from the delegation root instead of resolving the nested target.
const window = new Window();
const { document } = window;
document.body.innerHTML = `<ul id="root"><li><button data-work-order-id="WO-2"><span id="target">接单</span></button></li></ul>`;
const root = document.querySelector("#root");
const target = document.querySelector("#target");
let observedId = null;

root.addEventListener("click", (event) => {
  observedId = event.currentTarget.dataset.workOrderId;
});
target.dispatchEvent(new window.MouseEvent("click", { bubbles: true }));
const confused = observedId === undefined;

document.body.replaceChildren();
window.happyDOM.close();

if (confused) {
  console.error("EVENT_TARGET_CONFUSION");
  process.exitCode = 1;
} else {
  console.error(`FAULT_SETUP_FAILED observedId=${observedId}`);
  process.exitCode = 2;
}
