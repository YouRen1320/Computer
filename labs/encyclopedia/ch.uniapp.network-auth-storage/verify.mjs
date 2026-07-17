// Responsibility: map local network/auth/storage cases to the first trustworthy diagnosis offline.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url), 'utf8'))
const endpointFor = {
  development: 'https://dev-api.example.invalid',
  test: 'https://test-api.example.invalid',
  production: 'https://api.example.invalid'
}

function diagnose(input) {
  if (!input.allowlistedOrigins.includes(input.apiOrigin)) return 'REQUEST_DOMAIN_NOT_ALLOWLISTED'
  if (endpointFor[input.environment] !== input.apiOrigin) return 'ENVIRONMENT_CROSSWIRE'
  if (/Authorization|Bearer|SECRET_SENTINEL/i.test(input.logText)) return 'CREDENTIAL_EXPOSURE'
  if (!input.storage.validJson || input.storage.schemaVersion !== 1) return 'STORAGE_CORRUPTION'
  return 'PASS'
}

for (const input of cases) assert.equal(diagnose(input), input.expected, input.name)
console.log(`UNIAPP_NETWORK_AUTH_STORAGE_LAB_PASS cases=${cases.length} faults=4 evidence=offline-oracle`)
