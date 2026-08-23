import assert from "node:assert/strict";

// formatter is the deliberately shared composition dependency.
const formatter = {
  format(id, status) {
    return `${id}:${status}`;
  },
};

// behavior contains only immutable labels and receiver-based methods.
const behavior = {
  kind: "work-order",
  summary() {
    return this.formatter.format(this.id, this.status);
  },
  addNote(note) {
    this.notes.push(note);
  },
};

// createWorkOrder initializes a distinct mutable array for every receiver.
function createWorkOrder(id, status) {
  return Object.assign(Object.create(behavior), {
    id,
    status,
    formatter,
    notes: [],
  });
}

// The point call preserves workOrder as the dynamic receiver.
function renderSummary(workOrder) {
  return workOrder.summary();
}

// Customization shadows the prototype label only on the selected instance.
function customizeKind(workOrder) {
  workOrder.kind = "urgent";
}

const first = createWorkOrder("WO-1", "CREATED");
const second = createWorkOrder("WO-2", "ASSIGNED");
const rendered = renderSummary(first);
assert.equal(rendered, "WO-1:CREATED");

const detached = first.summary;
assert.equal(detached.call(second), "WO-2:ASSIGNED");
const expectedSecondKind = second.kind;
customizeKind(first);
assert.equal(first.kind, "urgent");
assert.equal(second.kind, expectedSecondKind);
assert.equal(Object.hasOwn(first, "kind"), true);
assert.equal(Object.hasOwn(second, "kind"), false);

first.addNote("checked");
assert.notStrictEqual(first.notes, second.notes);
assert.equal(second.notes.length, 0);
assert.strictEqual(first.summary, second.summary);

// WorkOrderView demonstrates a branded private status plus composed formatting.
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
