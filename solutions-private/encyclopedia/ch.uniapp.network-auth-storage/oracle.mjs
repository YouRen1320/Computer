// Responsibility: validate the private answer.json with the public network/auth/storage contract; violations exit nonzero.
import { readFile } from 'node:fs/promises'

const input = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
if (input.environment !== 'production' || input.apiOrigin !== input.allowedOrigin) problems.push('environment-origin')
if (/Authorization|Bearer|SECRET_SENTINEL/i.test(input.logText)) problems.push('credential-log')
if (input.storage.schemaVersion !== 1) problems.push('storage-version')
if (input.storage.environment !== input.environment) problems.push('storage-environment')
if (input.storage.subjectHash !== input.currentSubjectHash) problems.push('storage-owner')
if (Date.parse(input.storage.expiresAt) <= Date.parse(input.now)) problems.push('storage-expired')
if (problems.length) {
  console.error(`UNIAPP_NETWORK_AUTH_STORAGE_PRIVATE_FAIL problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('UNIAPP_NETWORK_AUTH_STORAGE_PRIVATE_PASS')
