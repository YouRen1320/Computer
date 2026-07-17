import { Window } from "happy-dom";

// Boolean attributes are true by presence; literal false does not set current state false.
const window = new Window();
const checkbox = window.document.createElement("input");
checkbox.type = "checkbox";
checkbox.setAttribute("checked", "false");
const attributePropertyDrifted = checkbox.checked !== false;
await window.happyDOM.close();
if (!attributePropertyDrifted) {
  throw new Error("attribute/property fault fixture did not drift");
}
console.error("ATTRIBUTE_PROPERTY_BOOLEAN_DRIFT");
process.exitCode = 1;
