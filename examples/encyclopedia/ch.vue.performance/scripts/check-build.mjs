import assert from 'node:assert/strict'
import { readdir, readFile, stat } from 'node:fs/promises'
import { resolve } from 'node:path'

// 构建预算读取真实 dist 文件；阈值绑定本示例，不冒充普适生产标准。
const assetsDir = resolve('dist/assets')
const files = await readdir(assetsDir)
const jsFiles = files.filter((file) => file.endsWith('.js'))
assert.ok(jsFiles.length >= 2, `expected entry and dynamic JS chunks, got ${jsFiles}`)

const sizes = await Promise.all(jsFiles.map(async (file) => (await stat(resolve(assetsDir, file))).size))
const totalBytes = sizes.reduce((sum, size) => sum + size, 0)
assert.ok(totalBytes <= 180 * 1024, `JS_BUDGET_EXCEEDED actual=${totalBytes} limit=${180 * 1024}`)

const appSource = await readFile(resolve('src/App.vue'), 'utf8')
for (const required of ['defineAsyncComponent', 'errorComponent', 'timeout', 'onError']) {
  assert.ok(appSource.includes(required), `ASYNC_RECOVERY_MISSING field=${required}`)
}

console.log(`VUE_PERFORMANCE_EXAMPLE_PASS chunks=${jsFiles.length} raw_js_bytes=${totalBytes}`)

