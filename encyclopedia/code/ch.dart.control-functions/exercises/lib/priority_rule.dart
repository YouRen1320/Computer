String priorityBand(int priority) {
  if (priority < 1 || priority > 5) return 'INVALID';
  if (priority >= 5) return 'URGENT';
  return 'NORMAL';
}
