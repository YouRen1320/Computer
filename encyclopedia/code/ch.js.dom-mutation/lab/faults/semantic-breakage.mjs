import { Window } from "happy-dom";

// This injected mapping appends a visual div directly beneath ul instead of a semantic li.
const window = new Window();
const list = window.document.createElement("ul");
list.append(window.document.createElement("div"));
const semanticStructureBroke = ![...list.children].every((child) => child.tagName === "LI");
list.replaceChildren();
await window.happyDOM.close();
if (!semanticStructureBroke) {
  throw new Error("semantic fault fixture did not drift");
}
console.error("SEMANTIC_DOM_BREAKAGE_UL_CHILD");
process.exitCode = 1;
