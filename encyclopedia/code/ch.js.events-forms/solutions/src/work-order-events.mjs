// resolveCommand owns the non-obvious target-to-command mapping and rejects nodes outside the root.
export function resolveCommand(event, root, ElementCtor) {
  if (!(event.target instanceof ElementCtor)) return null;
  const button = event.target.closest("button[data-action][data-work-order-id]");
  if (!button || !root.contains(button)) return null;
  return `${button.dataset.action}:${button.dataset.workOrderId}`;
}

// installInteraction owns two listener side effects and returns their symmetric cleanup operation.
export function installInteraction({ window, root, form, onCommand, onSubmit }) {
  const click = (event) => {
    const command = resolveCommand(event, root, window.Element);
    if (command) onCommand(command);
  };
  const submit = (event) => {
    const data = new window.FormData(form);
    const payload = `${data.get("status")}:${data.get("urgent") === "true"}`;
    event.preventDefault();
    onSubmit(payload);
  };

  root.addEventListener("click", click);
  form.addEventListener("submit", submit);
  return () => {
    root.removeEventListener("click", click);
    form.removeEventListener("submit", submit);
  };
}
