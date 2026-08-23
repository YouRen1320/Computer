import { readFile } from 'node:fs/promises'

// 私有解析复用公开合同形状，但仍以跨文件事实判定挂载是否一致。
const root = new URL('../', import.meta.url)
const [html, main, app] = await Promise.all([
  readFile(new URL('index.html', root), 'utf8'),
  readFile(new URL('src/main.ts', root), 'utf8'),
  readFile(new URL('src/App.vue', root), 'utf8'),
])

const host = html.match(/<div\s+id="([^"]+)"/u)?.[1]
const selector = main.match(/\.mount\(['"]#([^'"]+)['"]\)/u)?.[1]

if (!host || !selector || host !== selector) {
  console.error(`ENTRY_CONTRACT_FAILURE host=${host ?? 'missing'} selector=${selector ?? 'missing'}`)
  process.exit(8)
}
if (!app.includes('<template>') || !app.includes('<script setup lang="ts">') || !app.includes('<style scoped>')) {
  console.error('SFC_BLOCK_CONTRACT_FAILURE')
  process.exit(7)
}

console.log(`ENTRY_CONTRACT_OK host=#${host} selector=#${selector}`)
