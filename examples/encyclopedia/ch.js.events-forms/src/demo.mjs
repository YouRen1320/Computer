import { readFile } from "node:fs/promises";
import { Window } from "happy-dom";
import { installWorkOrderInteractions } from "./work-order-events.mjs";

// The checked-in HTML is the sole DOM data source so the example and browser fallback stay aligned.
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const window = new Window({ url: "https://factorycare.example/work-orders" });
window.document.write(html);
window.document.close();

const { document } = window;
const list = document.querySelector("#work-orders");
const form = document.querySelector("#work-order-filter");
const commands = [];
const submissions = [];

// A dynamically appended row proves that the stable list listener owns future descendants too.
const row = document.createElement("li");
row.dataset.workOrderId = "WO-2";
const button = document.createElement("button");
button.type = "button";
button.dataset.action = "assign";
button.dataset.workOrderId = "WO-2";
const label = document.createElement("span");
label.textContent = "接单 WO-2";
button.append(label);
row.append(button);
list.append(row);

const dispose = installWorkOrderInteractions({
  window,
  list,
  form,
  onCommand: (command) => commands.push(command),
  onSubmit: (payload) => submissions.push(payload),
});

// Dispatching on the nested span exercises target/currentTarget mapping through closest().
label.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
const submitEvent = new window.SubmitEvent("submit", { bubbles: true, cancelable: true });
const submitResult = form.dispatchEvent(submitEvent);
dispose();
label.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));

console.log(`command=${commands[0].action}:${commands[0].workOrderId}`);
console.log(`submit=${submissions[0].status}:${submissions[0].urgent}`);
console.log(`submitCanceled=${!submitResult && submitEvent.defaultPrevented}`);
console.log(`afterDisposeCommands=${commands.length}`);

// Clearing the simulator after primitive evidence avoids retaining DOM objects across teardown.
document.body.replaceChildren();
window.happyDOM.close();
