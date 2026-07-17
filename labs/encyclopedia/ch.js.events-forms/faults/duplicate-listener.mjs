import { Window } from "happy-dom";

// This fault models two mounts creating distinct closures for the same delegated side effect.
const window = new Window();
const { document } = window;
document.body.innerHTML = `<ul id="root"><li><button type="button"><span id="target">接单</span></button></li></ul>`;
const root = document.querySelector("#root");
const target = document.querySelector("#target");
let commands = 0;

const installBadMount = () => root.addEventListener("click", () => { commands += 1; });
installBadMount();
installBadMount();
target.dispatchEvent(new window.MouseEvent("click", { bubbles: true }));

document.body.replaceChildren();
window.happyDOM.close();

if (commands === 2) {
  console.error("DUPLICATE_EVENT_HANDLER");
  process.exitCode = 1;
} else {
  console.error(`FAULT_SETUP_FAILED duplicate commands=${commands}`);
  process.exitCode = 2;
}
