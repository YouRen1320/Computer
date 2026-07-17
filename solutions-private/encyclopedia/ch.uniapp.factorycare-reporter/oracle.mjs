import { readFile } from 'node:fs/promises'

// 职责：用同一稳定合同验证私有可通过 fixture；真实网络与发布仍是刻意非目标。
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
if (!a.e2eEvidence || !a.offlineReplayEvidence) problems.push('required-evidence')
if (problems.length) process.exit(1)
console.log('UNIAPP_FACTORYCARE_REPORTER_PRIVATE_PASS')
