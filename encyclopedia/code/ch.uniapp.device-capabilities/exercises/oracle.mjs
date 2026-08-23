// Responsibility: grade answer.json against observable permission/device contracts; violations exit nonzero.
import { readFile } from 'node:fs/promises'

const input = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
if (input.permissionResult.kind !== 'denied') problems.push('denial-result')
if (input.locationPayloadCreated) problems.push('denial-location-payload')
if (input.permissionRequestCount !== 1) problems.push('permission-loop')
if (input.scanCancelResult.kind !== 'cancelled') problems.push('scan-cancel')
if (input.unavailableLocationResult.kind !== 'unsupported') problems.push('location-unavailable')
if (!input.upload.attachmentId) problems.push('attachment-id')
if (!input.commit.idempotencyKey) problems.push('idempotency-key')
if (input.finalState !== 'commit-failed') problems.push('partial-commit-state')
if (problems.length) {
  console.error(`EXPECTED_UNIAPP_DEVICE_CAPABILITIES_RED problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('UNIAPP_DEVICE_CAPABILITIES_EXERCISE_PASS')
