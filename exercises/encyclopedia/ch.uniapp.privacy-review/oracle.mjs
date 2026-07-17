// Responsibility: grade answer.json against observable privacy-review contracts; violations exit nonzero.
import { readFile } from 'node:fs/promises'
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const p = []
if ([...a.codeCapabilities].sort().join(',') !== [...a.declarations].sort().join(',')) p.push('declaration-drift')
for (const capability of a.codeCapabilities) {
  const item = a.inventory.find((x) => x.capability === capability)
  if (!item) p.push(`inventory:${capability}`)
  else for (const key of ['purpose', 'source', 'retention', 'deletion', 'owner']) if (!item[key]) p.push(`${capability}:${key}`)
}
for (const s of a.sentinels) if (a.log.includes(s)) p.push(`log-sentinel:${s}`)
for (const [capability, core] of Object.entries(a.denialCases)) if (!core) p.push(`denial:${capability}`)
if (!a.releaseCommit) p.push('release-commit')
if (!a.deviceEvidence) p.push('device-evidence')
if (p.length) { console.error(`EXPECTED_UNIAPP_PRIVACY_REVIEW_RED problems=${p.join(',')}`); process.exit(1) }
console.log('UNIAPP_PRIVACY_REVIEW_EXERCISE_PASS')
