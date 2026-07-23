String priorityBand(int priority) {
  if (priority < 1 || priority > 5) return 'INVALID';

  return switch (priority) {
    1 || 2 => 'LOW',
    3 => 'MEDIUM',
    4 || 5 => 'URGENT',
    _ => 'INVALID',
  };
}

int countUrgentWindows(int totalWindows, {required int firstUrgentAt}) {
  var urgentCount = 0;
  for (var index = 0; index < totalWindows; index++) {
    if (index < firstUrgentAt) continue;
    urgentCount++;
  }
  return urgentCount;
}

int consumeRetryBudget(int requested, {int hardLimit = 3}) {
  var attempts = 0;
  while (attempts < requested) {
    if (attempts == hardLimit) break;
    attempts++;
  }
  return attempts;
}

int runAtLeastOnce(int requested) {
  var runs = 0;
  do {
    runs++;
  } while (runs < requested);
  return runs;
}

bool isDispatchable(int priority) => priority >= 1 && priority <= 5;
