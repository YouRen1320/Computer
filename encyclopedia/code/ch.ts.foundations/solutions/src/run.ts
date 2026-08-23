import { formatOwners, transitionText } from "./solution.js";

// This checked input covers both present and absent optional properties.
const labels = formatOwners(
  [
    { id: "WO-1", assignee: "Lin" },
    { id: "WO-2" }
  ],
  (id, owner) => id + ":" + owner
);

// Console output is the executable oracle; the library module stays side-effect free.
console.log("labels=" + labels.join("|"));
console.log("transition=" + transitionText(["CREATED", "CLOSED"]));
console.log("PRIVATE_TYPESCRIPT_SOLUTION_PASS");
