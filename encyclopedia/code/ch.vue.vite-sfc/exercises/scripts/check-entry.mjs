import { readFile } from 'node:fs/promises'

// 该检查器比较跨文件入口合同；它不把构建成功误当作浏览器已挂载。
const root = new URL('../', import.meta.url)
const [html, main, app] = await Promise.all([
  readFile(new URL('index.html', root), 'utf8'),
  readFile(new URL('src/main.ts', root), 'utf8'),
  readFile(new URL('src/App.vue', root), 'utf8'),
])

const host = html.match(/<div\s+id="([^"]+)"/u)?.[1]
const selector = main.match(/\.mount\(['"]#([^'"]+)['"]\)/u)?.[1]

if (!host || !selector) {
  console.error('ENTRY_CONTRACT_PARSE_FAILURE host-or-selector-missing')
  process.exit(7)
}

if (!app.includes('<template>') || !app.includes('<script setup lang="ts">') || !app.includes('<style scoped>')) {
  console.error('SFC_BLOCK_CONTRACT_FAILURE expected=template-script-setup-style-scoped')
  process.exit(7)
}

if (host !== selector) {
  console.error(`EXPECTED_FACTORYCARE_MOUNT_FAILURE host=#${host} selector=#${selector}`)
  process.exit(8)
}

console.log(`ENTRY_CONTRACT_OK host=#${host} selector=#${selector}`)
