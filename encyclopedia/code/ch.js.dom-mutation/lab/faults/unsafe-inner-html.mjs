import { Window } from "happy-dom";

// This injected sink parses markup-looking work-order data instead of creating text.
const window = new Window();
const list = window.document.createElement("ul");
const title = "<img data-injected src='x'>";
list.innerHTML = `<li><h3>${title}</h3></li>`;
const injectionCreatedNode = list.querySelector("[data-injected]") !== null;
list.replaceChildren();
await window.happyDOM.close();
if (!injectionCreatedNode) {
  throw new Error("innerHTML fault fixture did not create a node");
}
console.error("UNSAFE_INNER_HTML_CREATED_NODE");
process.exitCode = 1;
