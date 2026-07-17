// Starter responsibility: map a bubbled descendant click to one button command inside the root.
export function resolveCommand(event, root, ElementCtor) {
  if (!(event.target instanceof ElementCtor)) return null;

  // TODO: currentTarget is the list root; resolve from the actual target and guard root ownership.
  const button = event.currentTarget.closest("button[data-action][data-work-order-id]");
  if (!button || !root.contains(button)) return null;
  return `${button.dataset.action}:${button.dataset.workOrderId}`;
}
