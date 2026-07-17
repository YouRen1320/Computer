import { buildLabels } from "../src/work-orders.js";

// Fault injection: the formatter returns number although the contract requires string.
const rows = [{ id: "WO-1", status: "OPEN" }];
buildLabels(rows, (id, status, owner) => id.length + status.length + owner.length);
