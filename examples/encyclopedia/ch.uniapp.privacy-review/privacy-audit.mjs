// 职责：把“代码能力—数据清单—平台声明—降级证据”做可重复一致性检查。
export function auditPrivacy({ codeCapabilities, declarations, inventory, denialCases }) {
  const problems = []
  for (const capability of codeCapabilities) {
    if (!declarations.includes(capability)) problems.push(`UNDECLARED_CAPABILITY:${capability}`)
    const item = inventory.find((x) => x.capability === capability)
    if (!item) problems.push(`MISSING_INVENTORY:${capability}`)
    else for (const key of ['purpose', 'source', 'retention', 'deletion', 'owner']) if (!item[key]) problems.push(`MISSING_${key.toUpperCase()}:${capability}`)
  }
  for (const declared of declarations) if (!codeCapabilities.includes(declared)) problems.push(`UNUSED_DECLARATION:${declared}`)
  for (const test of denialCases) if (test.optional && !test.coreFlowAvailable) problems.push(`DENIAL_BLOCKS_CORE:${test.capability}`)
  return { valid: problems.length === 0, problems }
}

const allowedLogKeys = new Set(['event', 'target', 'appVersion', 'operationId', 'pathTemplate', 'status', 'errorCode', 'durationBucket'])
export function safeEvent(fields) {
  const output = {}
  for (const [key, value] of Object.entries(fields)) if (allowedLogKeys.has(key)) output[key] = value
  return output
}

export function containsSentinel(value, sentinels) {
  const serialized = JSON.stringify(value)
  return sentinels.some((sentinel) => serialized.includes(sentinel))
}
