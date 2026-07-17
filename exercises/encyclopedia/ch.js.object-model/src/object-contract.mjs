import assert from "node:assert/strict";

// formatter is a composed, stateless capability shared intentionally by every view.
const formatter = {
  format(id, status) {
    return `${id}:${status}`;
  },
};

// Exercise behavior deliberately contains a shared mutable field that must be moved to instance creation.
const behavior = {
  kind: "work-order",
  notes: [],
  summary() {
    return this.formatter.format(this.id, this.status);
  },
  addNote(note) {
    this.notes.push(note);
  },
};

// createWorkOrder owns instance initialization; TODO 3 is to create isolated mutable notes here.
function createWorkOrder(id, status) {
  return Object.assign(Object.create(behavior), { id, status, formatter });
}

// TODO 1: retain the receiver at the call site instead of invoking a detached function.
function renderSummary(workOrder) {
  const summary = workOrder.summary;
  return summary();
}

// TODO 2: customize only the target receiver, not the shared behavior prototype.
function customizeKind(workOrder) {
  Object.getPrototypeOf(workOrder).kind = "urgent";
}

const first = createWorkOrder("WO-1", "CREATED");
const second = createWorkOrder("WO-2", "ASSIGNED");
let rendered;
try {
  rendered = renderSummary(first);
} catch {
  assert.fail("THIS_BINDING_LOSS_EXERCISE");
}
assert.equal(rendered, "WO-1:CREATED");

const detached = first.summary;
assert.equal(detached.call(second), "WO-2:ASSIGNED");
const expectedSecondKind = second.kind;
customizeKind(first);
assert.equal(second.kind, expectedSecondKind, "PROTOTYPE_POLLUTION_EXERCISE");
assert.equal(first.kind, "urgent");

first.addNote("checked");
assert.notStrictEqual(first.notes, second.notes, "SHARED_INSTANCE_STATE_EXERCISE");
assert.equal(second.notes.length, 0);
assert.strictEqual(first.summary, second.summary);

// This class branch is already correct and protects the private-field and composition acceptance criteria.
class WorkOrderView {
  #status;

  constructor(id, status, composedFormatter) {
    this.id = id;
    this.#status = status;
    this.formatter = composedFormatter;
    this.notes = [];
  }

  summary() {
    return this.formatter.format(this.id, this.#status);
  }

  get status() {
    return this.#status;
  }
}

const classView = new WorkOrderView("WO-3", "CREATED", formatter);
assert.equal(classView.status, "CREATED");

console.log(`calls=direct:${rendered}|explicit:${detached.call(second)}`);
console.log(`kind=first:${first.kind}|second:${second.kind}`);
console.log(`notes=first:${first.notes.length}|second:${second.notes.length}`);
console.log("method=shared");
console.log(`class=${classView.summary()}|private:${classView.status}`);
