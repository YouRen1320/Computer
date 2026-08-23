import assert from 'node:assert/strict'
import { readdir, readFile } from 'node:fs/promises'
import { resolve } from 'node:path'

// 轻量 policy lint 只守边界绕过模式；生产项目仍应使用 ESLint/typescript-eslint。
async function collect(dir) {
  const entries = await readdir(dir, { withFileTypes: true })
  const files = []
  for (const entry of entries) {
    const path = resolve(dir, entry.name)
    if (entry.isDirectory()) files.push(...await collect(path))
    else if (entry.name.endsWith('.ts')) files.push(path)
  }
  return files
}

for (const file of await collect(resolve('src'))) {
  const source = await readFile(file, 'utf8')
  for (const forbidden of [/as\s+WorkOrder\b/, /as\s+unknown\s+as/, /:\s*any\b/]) {
    assert.ok(!forbidden.test(source), `QUALITY_GATE_BYPASS file=${file} pattern=${forbidden}`)
  }
}
console.log('policy-lint PASS')

