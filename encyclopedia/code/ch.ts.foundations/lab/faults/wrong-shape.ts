import { buildLabels } from "../src/work-orders.js";

// Fault injection: the source row omits the required status member.
const rows = [{ id: "WO-BROKEN" }];
buildLabels(rows, (id, status, owner) => id + status + owner);
