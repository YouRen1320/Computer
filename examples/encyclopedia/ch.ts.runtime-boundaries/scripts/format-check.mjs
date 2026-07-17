import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

// 轻量格式闸门检查尾随空白；完整项目由专用 formatter 负责自动排版。
for (const file of ['src/work-order-schema.ts', 'tests/work-order-schema.test.ts']) {
  const lines = (await readFile(file, 'utf8')).split('\n')
  assert.ok(lines.every((line) => !/[ \t]+$/.test(line)), `FORMAT_CHECK_FAILED file=${file}`)
}
console.log('format-check PASS')

