// Responsibility: grade answer.json against observable runtime contracts; violations exit nonzero without exposing a solution.
import { readFile } from 'node:fs/promises'

const input = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
const files = new Set(input.pageFiles)

for (const page of input.pages) {
  if (!files.has(page)) problems.push(`missing-file:${page}`)
}
if (input.appHooks.some((hook) => !['onLaunch', 'onShow', 'onHide', 'onError', 'onPageNotFound'].includes(hook))) {
  problems.push('page-hook-in-app')
}
if (/\b(?:document|window)\s*[.[]/.test(input.logicSource)) problems.push('browser-api-in-logic')
if (!input.pages.includes(input.routeTarget)) problems.push('route-target-not-registered')

if (problems.length > 0) {
  console.error(`EXPECTED_MINIAPP_RUNTIME_CONTRACT_RED problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('MINIAPP_RUNTIME_EXERCISE_PASS')
