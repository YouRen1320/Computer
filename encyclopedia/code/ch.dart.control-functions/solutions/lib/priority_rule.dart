String priorityBand(int priority) {
  if (priority < 1 || priority > 5) return 'INVALID';

  return switch (priority) {
    1 || 2 || 3 => 'NORMAL',
    4 || 5 => 'URGENT',
    _ => 'INVALID',
  };
}
