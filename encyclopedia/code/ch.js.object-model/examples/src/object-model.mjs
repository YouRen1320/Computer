import assert from "node:assert/strict";

// formatter is a stateless composed collaborator; it receives all data through explicit parameters.
const formatter = {
  format(id, status) {
    return `${id}:${status}`;
  },
};

// workOrderBehavior holds only shared behavior and a stable label, never per-instance mutable arrays.
const workOrderBehavior = {
  kind: "work-order",
  summary() {
    return this.formatter.format(this.id, this.status);
  },
  addNote(note) {
    this.notes.push(note);
  },
};

// createWorkOrder initializes all mutable state on each new receiver.
function createWorkOrder(id, status, composedFormatter) {
  const workOrder = Object.create(workOrderBehavior);
  Object.assign(workOrder, {
    id,
    status,
    formatter: composedFormatter,
    notes: [],
  });
  return workOrder;
}

const first = createWorkOrder("WO-1", "CREATED", formatter);
const second = createWorkOrder("WO-2", "ASSIGNED", formatter);
assert.equal(Object.getPrototypeOf(first), workOrderBehavior);
assert.equal(Object.hasOwn(first, "kind"), false);
assert.equal("kind" in first, true);
assert.equal(first.kind, "work-order");
assert.strictEqual(first.summary, second.summary);
assert.notStrictEqual(first.notes, second.notes);

first.kind = "urgent";
assert.equal(Object.hasOwn(first, "kind"), true);
assert.equal(first.kind, "urgent");
delete first.kind;
assert.equal(first.kind, "work-order");

const detached = first.summary;
assert.throws(() => detached(), TypeError);
assert.equal(detached.call(second), "WO-2:ASSIGNED");
const boundToSecond = detached.bind(second);
assert.equal(boundToSecond(), "WO-2:ASSIGNED");

// WorkOrderView demonstrates prototype methods plus per-instance branded private status.
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

  addNote(note) {
    this.notes.push(note);
  }

  get status() {
    return this.#status;
  }
}

const classFirst = new WorkOrderView("WO-3", "CREATED", formatter);
const classSecond = new WorkOrderView("WO-4", "ASSIGNED", formatter);
classFirst.addNote("checked");
assert.equal(classFirst.status, "CREATED");
assert.equal(classSecond.notes.length, 0);
assert.strictEqual(classFirst.summary, classSecond.summary);
assert.strictEqual(classFirst.formatter, classSecond.formatter);

console.log("prototype-link=true");
console.log("lookup-kind=own:false,in:true,value:work-order");
console.log("shadow-kind=urgent");
console.log("revealed-kind=work-order");
console.log(`method-shared=${first.summary === second.summary}`);
console.log(`call-direct=${first.summary()}`);
console.log(`call-explicit=${detached.call(second)}`);
console.log(`call-bound=${boundToSecond()}`);
console.log(`class-private=${classFirst.summary()}`);
console.log(`instance-state-isolated=${classFirst.notes !== classSecond.notes}`);
console.log(`composition-shared=${classFirst.formatter === classSecond.formatter}`);
