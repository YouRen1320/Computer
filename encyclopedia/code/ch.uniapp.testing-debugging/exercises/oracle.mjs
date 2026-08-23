// Responsibility: grade answer.json against observable testing/debugging contracts; violations exit nonzero.
import { readFile } from 'node:fs/promises'
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
if (a.mockShape !== a.hostShape) problems.push('mock-host-shape')
if (a.buildId !== a.mapBuildId) problems.push('source-map-build')
if (a.claim === 'device-passed' && a.carrier !== 'physical-device') problems.push('device-carrier')
for (const key of ['target', 'runtimeVersion', 'device', 'os', 'commit', 'artifactChecksum', 'expected', 'actual']) if (!a[key]) problems.push(key)
if (!Array.isArray(a.steps) || a.steps.length === 0) problems.push('steps')
if (problems.length) { console.error(`EXPECTED_UNIAPP_TESTING_DEBUGGING_RED problems=${problems.join(',')}`); process.exit(1) }
console.log('UNIAPP_TESTING_DEBUGGING_EXERCISE_PASS')
