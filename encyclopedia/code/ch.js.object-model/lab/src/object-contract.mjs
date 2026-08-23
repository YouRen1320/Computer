import assert from "node:assert/strict";

// formatter is the composed output policy; object instances do not inherit from it.
const formatter = {
  format(id, status) {
    return `${id}:${status}`;
  },
};

// behavior centralizes methods while leaving mutable instance data to the factory.
const behavior = {
  kind: "work-order",
  summary() {
    return this.formatter.format(this.id, this.status);
  },
  addNote(note) {
    this.notes.push(note);
  },
};

// createWorkOrder owns initialization side effects and creates a fresh notes array per receiver.
function createWorkOrder(id, status) {
  const result = Object.create(behavior);
  Object.assign(result, { id, status, formatter, notes: [] });
  return result;
}

const first = createWorkOrder("WO-1", "CREATED");
const second = createWorkOrder("WO-2", "ASSIGNED");

assert.equal(Object.getPrototypeOf(first), behavior);
assert.equal(Object.hasOwn(first, "kind"), false);
assert.equal("kind" in first, true);
assert.equal(first.kind, "work-order");

first.kind = "urgent";
assert.equal(Object.hasOwn(first, "kind"), true);
assert.equal(first.kind, "urgent");
delete first.kind;
assert.equal(Object.hasOwn(first, "kind"), false);
assert.equal(first.kind, "work-order");

const detached = first.summary;
assert.throws(() => detached(), TypeError);
assert.equal(first.summary(), "WO-1:CREATED");
assert.equal(detached.call(second), "WO-2:ASSIGNED");
assert.equal(detached.bind(second)(), "WO-2:ASSIGNED");
assert.strictEqual(first.summary, second.summary);
assert.notStrictEqual(first.notes, second.notes);
first.addNote("checked");
assert.equal(second.notes.length, 0);

// The class uses private status and the same composed formatter without sharing mutable notes.
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

const classFirst = new WorkOrderView("WO-3", "CREATED", formatter);
const classSecond = new WorkOrderView("WO-4", "ASSIGNED", formatter);
assert.strictEqual(classFirst.summary, classSecond.summary);
assert.notStrictEqual(classFirst.notes, classSecond.notes);
assert.strictEqual(classFirst.formatter, classSecond.formatter);

console.log("lookup=kind:prototype");
console.log("shadow=kind:instance");
console.log("delete=kind:prototype");
console.log("calls=direct:WO-1:CREATED|call:WO-2:ASSIGNED|bound:WO-2:ASSIGNED");
console.log("identity=method:shared|notes:isolated");
console.log(`class=${classFirst.summary()}|private:${classFirst.status}`);
console.log("composition=formatter:shared");
