// Responsibility: grade answer.json against observable package/performance contracts; violations exit nonzero.
import { readFile } from 'node:fs/promises'
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
if (a.graph.reporter?.includes('history') && a.graph.history?.includes('reporter')) problems.push('package-cycle')
if (a.report.mainBytes > a.budget.mainBytes) problems.push('main-budget')
if (Object.values(a.report.subpackages).some((n) => n > a.budget.subpackageBytes)) problems.push('subpackage-budget')
if (a.report.maxAssetBytes > a.budget.singleAssetBytes) problems.push('asset-budget')
if (a.cache.schemaVersion !== a.cache.currentVersion && a.cache.accepted) problems.push('stale-cache')
if (a.preloadBeforeInteractiveBytes !== 0) problems.push('preload-before-interactive')
if (a.samples.p50 > a.budget.p50 || a.samples.p95 > a.budget.p95) problems.push('cold-start-budget')
for (const [name, ok] of Object.entries(a.regressions)) if (!ok) problems.push(`regression:${name}`)
if (problems.length) { console.error(`EXPECTED_UNIAPP_PACKAGES_PERFORMANCE_RED problems=${problems.join(',')}`); process.exit(1) }
console.log('UNIAPP_PACKAGES_PERFORMANCE_EXERCISE_PASS')
