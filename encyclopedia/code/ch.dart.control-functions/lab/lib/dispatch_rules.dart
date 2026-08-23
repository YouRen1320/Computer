String dispatchDecision({
  required int priority,
  required bool assigneeAvailable,
  int retryLimit = 3,
}) {
  if (priority < 1 || priority > 5) return 'REJECT_INVALID_PRIORITY';
  if (!assigneeAvailable) return 'QUEUE_RETRY_$retryLimit';

  return switch (priority) {
    1 || 2 => 'NORMAL_QUEUE',
    3 => 'EXPEDITED_QUEUE',
    4 || 5 => 'URGENT_DISPATCH',
    _ => 'REJECT_INVALID_PRIORITY',
  };
}

int boundedAttempts(int requested, {int limit = 3}) {
  var attempts = 0;
  for (var index = 0; index < requested; index++) {
    if (index >= limit) break;
    attempts++;
  }
  return attempts;
}
