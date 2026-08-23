import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { renderRoute } from '../src/render-model.mjs'

// 源码合同检查避免模型与示例页面完全脱节，但不冒充真实 Nuxt 编译。
const config = await readFile('nuxt.config.ts', 'utf8')
for (const token of ["'/ssr'", "'/ssg'", "'/csr'", 'prerender', 'ssr: false']) assert.ok(config.includes(token))

for (const page of ['ssr', 'ssg', 'csr']) {
  const source = await readFile(`app/pages/${page}.vue`, 'utf8')
  assert.ok(source.includes('useAsyncData'))
  assert.ok(source.includes(`work-orders:${page}:v1`))
}

const ssr = renderRoute('ssr')
const ssg = renderRoute('ssg')
const csr = renderRoute('csr')
assert.ok(ssr.initialHtml.includes('泵体温度异常'))
assert.ok(ssg.initialHtml.includes('泵体温度异常'))
assert.ok(!csr.initialHtml.includes('泵体温度异常'))
assert.equal(ssr.browserFetches, 0)
assert.equal(ssg.browserFetches, 0)
assert.equal(csr.browserFetches, 1)

const serialized = JSON.stringify({ ssr: ssr.payload, ssg: ssg.payload })
for (const forbidden of ['secret', 'token', 'contactPhone']) assert.ok(!serialized.includes(forbidden))

console.log('NUXT_RENDERING_HYDRATION_EXAMPLE_PASS routes=3 payload_reuse=2')

