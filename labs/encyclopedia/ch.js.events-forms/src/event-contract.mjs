import { Window } from "happy-dom";

// The fixture is a fixed semantic tree; all observations are reduced to primitive trace values.
const window = new Window({ url: "https://factorycare.example/work-orders" });
const { document } = window;
document.body.innerHTML = `
  <main>
    <ul id="work-orders">
      <li><button type="button" data-action="assign" data-work-order-id="WO-2"><span id="label">接单</span></button></li>
    </ul>
    <form id="filter" action="/work-orders" method="get">
      <label for="status">状态</label>
      <select id="status" name="status"><option value="ASSIGNED" selected>处理中</option></select>
      <input type="checkbox" name="urgent" value="true" checked>
      <button type="submit">筛选</button>
    </form>
  </main>`;

const list = document.querySelector("#work-orders");
const button = list.querySelector("button");
const label = document.querySelector("#label");
const form = document.querySelector("#filter");
const order = [];
const commands = [];
const submissions = [];

// These three listeners expose capture, target, and bubble order without serializing DOM objects.
const documentCapture = () => order.push("document-capture");
const buttonTarget = () => order.push("button-target");
const listBubble = () => order.push("list-bubble");
document.addEventListener("click", documentCapture, { capture: true });
button.addEventListener("click", buttonTarget);
list.addEventListener("click", listBubble);

// Delegation maps a nested target to one command and never treats the list as the business button.
const handleClick = (event) => {
  if (!(event.target instanceof window.Element)) return;
  const actionButton = event.target.closest("button[data-action][data-work-order-id]");
  if (!actionButton || !list.contains(actionButton)) return;
  commands.push(`${actionButton.dataset.action}:${actionButton.dataset.workOrderId}`);
};

// Submission preserves name/value mapping and cancels only after the enhanced payload is ready.
const handleSubmit = (event) => {
  const data = new window.FormData(form);
  const payload = `${data.get("status")},${data.get("urgent")}`;
  event.preventDefault();
  submissions.push(payload);
};

list.addEventListener("click", handleClick);
form.addEventListener("submit", handleSubmit);
label.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
const submitEvent = new window.SubmitEvent("submit", { bubbles: true, cancelable: true });
const submitResult = form.dispatchEvent(submitEvent);

list.removeEventListener("click", handleClick);
form.removeEventListener("submit", handleSubmit);
label.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
form.dispatchEvent(new window.SubmitEvent("submit", { bubbles: true, cancelable: true }));

console.log(`order=${order.slice(0, 3).join(">")}`);
console.log(`command=${commands[0]}`);
console.log(`submit=${submissions[0]}`);
console.log(`canceled=${!submitResult && submitEvent.defaultPrevented}`);
console.log(`afterDispose=${commands.length},${submissions.length}`);

// Teardown follows all primitive comparisons so simulator objects cannot affect assertion formatting.
document.body.replaceChildren();
window.happyDOM.close();
