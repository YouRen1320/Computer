import { readFile } from "node:fs/promises";
import { Window } from "happy-dom";
import { installInteraction } from "./work-order-events.mjs";

// This runner reduces DOM behavior to four fixed primitive assertions for reproducible evidence.
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const window = new Window();
window.document.write(html);
window.document.close();
const root = window.document.querySelector("#work-orders");
const form = window.document.querySelector("#filter");
const target = window.document.querySelector("#target");
const commands = [];
const submissions = [];

const dispose = installInteraction({
  window,
  root,
  form,
  onCommand: (command) => commands.push(command),
  onSubmit: (payload) => submissions.push(payload),
});

target.dispatchEvent(new window.MouseEvent("click", { bubbles: true }));
const submitEvent = new window.SubmitEvent("submit", { bubbles: true, cancelable: true });
const dispatchResult = form.dispatchEvent(submitEvent);
dispose();
target.dispatchEvent(new window.MouseEvent("click", { bubbles: true }));

console.log(`command=${commands[0]}`);
console.log(`submit=${submissions[0]}`);
console.log(`canceled=${!dispatchResult && submitEvent.defaultPrevented}`);
console.log(`afterDispose=${commands.length},${submissions.length}`);

window.document.body.replaceChildren();
window.happyDOM.close();
