// 职责：把包体、依赖、缓存和样本判定实现为可重复的纯函数。
export function checkPackageBudget(report, budget) {
  const problems = []
  if (report.mainBytes > budget.mainBytes) problems.push('MAIN_PACKAGE_BUDGET')
  for (const [name, bytes] of Object.entries(report.subpackages)) {
    if (bytes > budget.subpackageBytes) problems.push(`SUBPACKAGE_BUDGET:${name}`)
  }
  for (const asset of report.assets) if (asset.bytes > budget.singleAssetBytes) problems.push(`ASSET_BUDGET:${asset.path}`)
  return { valid: problems.length === 0, problems }
}

export function findPackageCycle(graph) {
  const visiting = new Set()
  const visited = new Set()
  function visit(node, path) {
    if (visiting.has(node)) return [...path, node]
    if (visited.has(node)) return null
    visiting.add(node)
    for (const next of graph[node] ?? []) {
      const cycle = visit(next, [...path, node])
      if (cycle) return cycle
    }
    visiting.delete(node)
    visited.add(node)
    return null
  }
  for (const node of Object.keys(graph)) {
    const cycle = visit(node, [])
    if (cycle) return cycle
  }
  return null
}

export function decodeCache(envelope, context) {
  if (!envelope || typeof envelope !== 'object') return { kind: 'invalid', reason: 'shape' }
  if (envelope.schemaVersion !== context.schemaVersion) return { kind: 'invalid', reason: 'version' }
  if (envelope.environment !== context.environment) return { kind: 'invalid', reason: 'environment' }
  if (envelope.subjectHash !== context.subjectHash) return { kind: 'invalid', reason: 'owner' }
  if (Date.parse(envelope.expiresAt) <= Date.parse(context.now)) return { kind: 'invalid', reason: 'expired' }
  return { kind: 'ok', value: envelope.payload }
}

export function summarizeSamples(samples) {
  if (!samples.length) throw new Error('NO_SAMPLES')
  const sorted = [...samples].sort((a, b) => a - b)
  const pick = (ratio) => sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * ratio) - 1)]
  return { count: sorted.length, min: sorted[0], p50: pick(0.5), p95: pick(0.95), max: sorted.at(-1) }
}
