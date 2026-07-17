// Responsibility: grade answer.json against observable platform-adapter contracts; violations exit nonzero.
import { readFile } from 'node:fs/promises'

const input = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
for (const target of ['h5', 'mp-weixin']) if (!input.targetsBuilt.includes(target)) problems.push(`target:${target}`)
if (JSON.stringify(input.modules.h5) !== JSON.stringify(['h5-adapter'])) problems.push('h5-module-boundary')
if (JSON.stringify(input.modules['mp-weixin']) !== JSON.stringify(['weixin-adapter'])) problems.push('mp-module-boundary')
for (const hit of ['h5:supported', 'h5:unsupported', 'mp-weixin:supported', 'mp-weixin:unsupported']) {
  if (!input.branchHits.includes(hit)) problems.push(`branch:${hit}`)
}
if (!input.fallbacks['h5:share']) problems.push('h5-share-fallback')
if (!input.fallbacks['mp-weixin:file']) problems.push('mp-file-fallback')
if (problems.length) {
  console.error(`EXPECTED_UNIAPP_PLATFORM_CONDITIONAL_RED problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('UNIAPP_PLATFORM_CONDITIONAL_EXERCISE_PASS')
