import { Window } from "happy-dom";

// This fault cancels native submission before discovering that the enhanced path is unavailable.
const window = new Window();
const { document } = window;
document.body.innerHTML = `<form id="filter" action="/work-orders" method="get"><input name="status" value="CREATED"><button>筛选</button></form>`;
const form = document.querySelector("#filter");
let enhancedSubmissions = 0;
const enhancementReady = false;

form.addEventListener("submit", (event) => {
  event.preventDefault();
  if (!enhancementReady) return;
  enhancedSubmissions += 1;
});

const event = new window.SubmitEvent("submit", { bubbles: true, cancelable: true });
const dispatchResult = form.dispatchEvent(event);
const lost = !dispatchResult && event.defaultPrevented && enhancedSubmissions === 0;

document.body.replaceChildren();
window.happyDOM.close();

if (lost) {
  console.error("DEFAULT_ACTION_LOSS");
  process.exitCode = 1;
} else {
  console.error("FAULT_SETUP_FAILED default action was not lost");
  process.exitCode = 2;
}
