// This module owns delegation and form listeners; callers own command and submission side effects.
export function resolveCommand(event, root, ElementCtor) {
  if (!(event.target instanceof ElementCtor)) return null;
  const button = event.target.closest("button[data-action][data-work-order-id]");
  if (!button || !root.contains(button)) return null;
  return {
    action: button.dataset.action,
    workOrderId: button.dataset.workOrderId,
  };
}

// The mapping preserves the form's name/value contract and converts only known filter fields.
export function mapFilterPayload(formData) {
  const status = formData.get("status");
  if (status !== "CREATED" && status !== "ASSIGNED") {
    throw new TypeError("status must be a supported filter value");
  }
  return { status, urgent: formData.get("urgent") === "true" };
}

// Installation adds exactly two listeners and returns the only cleanup boundary for those effects.
export function installWorkOrderInteractions({ window, list, form, onCommand, onSubmit }) {
  const handleClick = (event) => {
    const command = resolveCommand(event, list, window.Element);
    if (command) onCommand(command);
  };

  const handleSubmit = (event) => {
    const payload = mapFilterPayload(new window.FormData(form));
    event.preventDefault();
    onSubmit(payload);
  };

  list.addEventListener("click", handleClick);
  form.addEventListener("submit", handleSubmit);

  return () => {
    list.removeEventListener("click", handleClick);
    form.removeEventListener("submit", handleSubmit);
  };
}
