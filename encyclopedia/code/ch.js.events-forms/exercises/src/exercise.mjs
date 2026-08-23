import { readFile } from "node:fs/promises";
import { Window } from "happy-dom";
import { resolveCommand } from "./work-order-events.mjs";

// The checked-in HTML and one nested click are the fixed exercise inputs.
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const window = new Window();
window.document.write(html);
window.document.close();
const root = window.document.querySelector("#work-orders");
const target = window.document.querySelector("#target");
const commands = [];

root.addEventListener("click", (event) => {
  const command = resolveCommand(event, root, window.Element);
  if (command) commands.push(command);
});
target.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
const actual = commands.join(",");

window.document.body.replaceChildren();
window.happyDOM.close();

if (actual !== "assign:WO-2") {
  throw new Error(`EVENT_TARGET_CONFUSION_EXERCISE: expected assign:WO-2, received ${actual || "<empty>"}`);
}

console.log(actual);
