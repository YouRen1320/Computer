import assert from "node:assert/strict";

// The injected fault places a mutable notes array on the prototype rather than each instance.
const behavior = {
  notes: [],
  addNote(note) {
    this.notes.push(note);
  },
};
const first = Object.create(behavior);
const second = Object.create(behavior);
first.addNote("checked");
assert.notStrictEqual(first.notes, second.notes, "SHARED_INSTANCE_STATE_NOT_ISOLATED");
