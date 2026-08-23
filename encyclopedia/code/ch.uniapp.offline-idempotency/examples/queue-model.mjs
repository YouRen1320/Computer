// 职责：用纯状态转移表达离线命令，确保重放不重新生成幂等键。
export function enqueue(input, context) {
  return {
    commandId: context.commandId, idempotencyKey: context.idempotencyKey,
    payloadHash: context.payloadHash, subjectHash: context.subjectHash, environment: context.environment,
    payload: input, state: 'pending', attemptCount: 0, nextAttemptAt: null, lastErrorCode: null
  }
}

export function start(command) {
  if (!['pending', 'waiting-retry'].includes(command.state)) throw new Error('NOT_REPLAYABLE')
  return { ...command, state: 'in-flight' }
}

export function applyOutcome(command, outcome, clock) {
  if (command.state !== 'in-flight') throw new Error('NOT_IN_FLIGHT')
  if (['success', 'duplicate-success'].includes(outcome.kind)) {
    return { ...command, state: 'completed', workOrderId: outcome.workOrderId, nextAttemptAt: null }
  }
  if (outcome.kind === 'unauthenticated') return { ...command, state: 'blocked-auth', lastErrorCode: 'UNAUTHENTICATED' }
  if (outcome.kind === 'conflict') return { ...command, state: 'conflict', lastErrorCode: outcome.code }
  if (outcome.kind === 'permanent') return { ...command, state: 'dead-letter', lastErrorCode: outcome.code }
  if (outcome.kind === 'temporary') {
    const attemptCount = command.attemptCount + 1
    if (attemptCount >= clock.maxAttempts) return { ...command, attemptCount, state: 'dead-letter', lastErrorCode: outcome.code }
    return { ...command, attemptCount, state: 'waiting-retry', nextAttemptAt: clock.nextAttemptAt(attemptCount), lastErrorCode: outcome.code }
  }
  throw new Error('UNKNOWN_OUTCOME')
}

export function selectDue(commands, now) {
  // 排序职责：永久/身份/冲突状态不参与；一条毒消息不能阻塞其他到期命令。
  return commands.filter((c) => c.state === 'pending' || (c.state === 'waiting-retry' && c.nextAttemptAt <= now))
    .sort((a, b) => a.commandId.localeCompare(b.commandId))[0] ?? null
}

export function belongsTo(command, context) {
  return command.subjectHash === context.subjectHash && command.environment === context.environment
}
