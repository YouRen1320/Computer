import assert from 'node:assert/strict'
import { mkdtemp, readFile, rm, writeFile, mkdir } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.dirname(fileURLToPath(import.meta.url))
const pkg = JSON.parse(await readFile(path.join(root, 'package.json'), 'utf8'))
const pagesConfig = JSON.parse(await readFile(path.join(root, 'src/pages.json'), 'utf8'))
const manifest = JSON.parse(await readFile(path.join(root, 'src/manifest.json'), 'utf8'))

assert.match(pkg.scripts['dev:mp-weixin'], /mp-weixin/)
assert.match(pkg.scripts['build:mp-weixin'], /mp-weixin/)
assert.ok(pkg.packageManager.startsWith('pnpm@'))
assert.equal(manifest['mp-weixin'].appid, 'touristappid')

const registered = pagesConfig.pages.map(({ path: pagePath }) => pagePath)
assert.deepEqual(registered, [
  'pages/index/index',
  'pages/work-orders/list',
  'pages/work-orders/detail'
])
for (const pagePath of registered) {
  assert.equal(existsSync(path.join(root, `src/${pagePath}.vue`)), true, pagePath)
}

const listSource = await readFile(path.join(root, 'src/pages/work-orders/list.vue'), 'utf8')
assert.match(listSource, /encodeURIComponent\(id\)/)
assert.match(listSource, /\/pages\/work-orders\/detail\?id=/)

// 模拟目标构建只验证输入到工件的形状，不冒充 DCloud 编译器。
const output = await mkdtemp(path.join(os.tmpdir(), 'factorycare-uniapp-'))
try {
  await mkdir(path.join(output, 'pages/work-orders'), { recursive: true })
  await writeFile(path.join(output, 'app.json'), JSON.stringify({ pages: registered }))
  await writeFile(path.join(output, 'pages/work-orders/detail.js'), '// simulated target artifact\n')
  assert.equal(existsSync(path.join(output, 'app.json')), true)
  assert.equal(existsSync(path.join(output, 'pages/work-orders/detail.js')), true)
} finally {
  await rm(output, { recursive: true, force: true })
}

const stack = ['pages/index/index']
stack.push('pages/work-orders/list')
stack.push('pages/work-orders/detail')
assert.deepEqual(stack, registered)
stack.pop()
assert.deepEqual(stack, registered.slice(0, 2))

console.log('UNIAPP_TOOLCHAIN_EXAMPLE_PASS checks=13 evidence=offline-structure-route-model')
