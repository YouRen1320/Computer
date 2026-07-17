import { readFile } from 'node:fs/promises'

// 职责：检查公开报修集成证据包，不把离线字段绿灯误报成真机 E2E。
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
if (Object.keys(a.resolveResponse).sort().join(',') !== 'assetId,displayName') problems.push('resolve-field-allowlist')
if (!['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].includes(a.form.priority)) problems.push('priority-contract')
if (a.form.description.length < 10) problems.push('description-contract')
for (const id of a.form.attachmentIds) if (a.attachmentStates[id] !== 'ready') problems.push(`attachment-not-ready:${id}`)
if (!a.operationId || !a.firstIdempotencyKey || a.firstIdempotencyKey !== a.retryIdempotencyKey) problems.push('unstable-submit-identity')
if (a.cameraDenied && (!a.manualCodeAvailable || !a.textOnlySubmitAvailable)) problems.push('permission-fallback')
const statuses = ['CREATED', 'TRIAGED', 'ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'PENDING_PARTS', 'PENDING_APPROVAL', 'RESOLVED', 'VERIFIED', 'CLOSED', 'REOPENED', 'CANCELLED']
if (!statuses.includes(a.serverStatus)) problems.push('invented-work-order-status')
if (!a.release.contractDigest || a.release.buildId !== a.release.evidenceBuildId) problems.push('release-evidence')
if (!a.e2eEvidence) problems.push('e2e-evidence')
if (!a.offlineReplayEvidence) problems.push('offline-replay-evidence')
if (problems.length) {
  console.error(`EXPECTED_UNIAPP_FACTORYCARE_REPORTER_RED problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('UNIAPP_FACTORYCARE_REPORTER_EXERCISE_PASS')
