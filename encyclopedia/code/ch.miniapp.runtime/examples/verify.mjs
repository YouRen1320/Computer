import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { fileURLToPath } from 'node:url'

const root = path.dirname(fileURLToPath(import.meta.url))
const trace = []
const stack = []

async function loadDefinition(relativePath, registrationName) {
  let definition
  const source = await readFile(path.join(root, relativePath), 'utf8')
  const sandbox = {
    console: { info: (...args) => trace.push(args[0]) },
    wx: {
      navigateTo({ url }) {
        stack.push(url.split('?')[0].replace(/^\//, ''))
      }
    },
    [registrationName]: (value) => { definition = value }
  }
  vm.runInNewContext(source, sandbox, { filename: relativePath })
  assert.ok(definition, `${registrationName} was not registered`)
  return definition
}

function pageInstance(definition) {
  return {
    ...definition,
    data: structuredClone(definition.data ?? {}),
    setData(patch) {
      // 受控宿主只模拟本章需要的数据合并，不冒充真实渲染器。
      Object.assign(this.data, patch)
    }
  }
}

const config = JSON.parse(await readFile(path.join(root, 'app.json'), 'utf8'))
assert.deepEqual(config.pages, ['pages/index/index', 'pages/detail/detail'])
for (const page of config.pages) {
  for (const extension of ['js', 'json', 'wxml', 'wxss']) {
    assert.equal(existsSync(path.join(root, `${page}.${extension}`)), true, `${page}.${extension}`)
  }
}

const app = await loadDefinition('app.js', 'App')
const index = pageInstance(await loadDefinition('pages/index/index.js', 'Page'))
const detail = pageInstance(await loadDefinition('pages/detail/detail.js', 'Page'))

app.onLaunch({ scene: 1001 })
app.onShow()
stack.push('pages/index/index')
index.onLoad()
index.onShow()
index.onReady()
index.onHide()
index.openDetail()
detail.onLoad({ id: 'WO-1001' })
detail.onShow()
detail.onReady()
assert.equal(detail.data.id, 'WO-1001')
assert.equal(detail.browserDomAvailability(), 'undefined')
detail.onUnload()
stack.pop()
index.onShow()
app.onHide()

assert.deepEqual(stack, ['pages/index/index'])
assert.deepEqual(trace, [
  'app:onLaunch', 'app:onShow',
  'index:onLoad', 'index:onShow', 'index:onReady', 'index:onHide',
  'detail:onLoad', 'detail:onShow', 'detail:onReady', 'detail:onUnload',
  'index:onShow', 'app:onHide'
])

console.log('MINIAPP_RUNTIME_EXAMPLE_PASS checks=15 evidence=offline-host-model')
