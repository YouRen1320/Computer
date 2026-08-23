// 职责：把构建身份、灰度决策、回退目标和监控事件关联为可机械检查的发布证据。
const forbiddenEventKeys = new Set(['token', 'authorization', 'coordinates', 'phone', 'description', 'requestBody', 'attachmentUrl'])

export function auditRelease({ candidate, grayPlan, events }) {
  const problems = []
  for (const key of ['productVersion', 'buildId', 'commit', 'target', 'environment', 'configDigest', 'contractDigest', 'artifactDigest']) {
    if (!candidate[key]) problems.push(`MISSING_CANDIDATE_${key.toUpperCase()}`)
  }
  if (!['staging', 'production'].includes(candidate.environment)) problems.push('UNAPPROVED_ENVIRONMENT')
  if (candidate.environment === 'production' && candidate.apiOrigin.includes('localhost')) problems.push('PRODUCTION_LOCALHOST')
  if (grayPlan.buildId !== candidate.buildId) problems.push('GRAY_BUILD_MISMATCH')
  for (const key of ['scope', 'baseline', 'successCondition', 'stopCondition', 'rollbackCondition', 'decisionOwner']) {
    if (!grayPlan[key]) problems.push(`MISSING_GRAY_${key.toUpperCase()}`)
  }
  if (grayPlan.rollbackBuildId === candidate.buildId || !grayPlan.rollbackBuildId) problems.push('INVALID_ROLLBACK_TARGET')
  for (const event of events) {
    if (event.buildId !== candidate.buildId) problems.push(`EVENT_BUILD_MISMATCH:${event.eventName}`)
    for (const key of Object.keys(event)) if (forbiddenEventKeys.has(key)) problems.push(`SENSITIVE_EVENT_KEY:${key}`)
  }
  return { valid: problems.length === 0, problems }
}

// 数据来源：调用方只传入已通过 allowlist 的结构化事件；未知业务状态不得整体序列化。
export function createSafeEvent({ eventName, severity, buildId, routeTemplate, operation, errorCode, requestId, occurredAt }) {
  return { eventName, severity, buildId, routeTemplate, operation, errorCode, requestId, occurredAt }
}
