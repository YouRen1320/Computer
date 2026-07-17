// Responsibility: grade answer.json against observable toolchain/route contracts; violations exit nonzero.
import { readFile } from 'node:fs/promises'

const input = JSON.parse(await readFile(new URL('./project.json', import.meta.url), 'utf8'))
const problems = []
const files = new Set(input.files)

if (input.devTarget !== 'mp-weixin') problems.push('dev-target')
if (input.buildTarget !== 'mp-weixin') problems.push('build-target')
for (const page of input.pages) if (!files.has(page)) problems.push(`missing:${page}`)
if (!input.directDetailInitializesItself) problems.push('direct-entry')
if (!input.routeUsesEncodeURIComponent) problems.push('route-encoding')

if (problems.length > 0) {
  console.error(`EXPECTED_UNIAPP_TOOLCHAIN_RED problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('UNIAPP_TOOLCHAIN_EXERCISE_PASS')
