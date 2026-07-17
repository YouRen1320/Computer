import { readFile } from 'node:fs/promises'

// 静态检查补足 HTTP 200 不能证明挂载选择器一致这一运行期盲区。
const root = new URL('../', import.meta.url)
const [html, main] = await Promise.all([
  readFile(new URL('index.html', root), 'utf8'),
  readFile(new URL('src/main.ts', root), 'utf8'),
])
const host = html.match(/id="([^"]+)"/u)?.[1]
const selector = main.match(/\.mount\(['"]#([^'"]+)['"]\)/u)?.[1]
if (host !== 'factorycare-root' || selector !== host) {
  console.error(`ENTRY_MOUNT_FAILURE host=${host ?? 'missing'} selector=${selector ?? 'missing'}`)
  process.exit(8)
}
console.log('ENTRY_MOUNT_OK host=#factorycare-root')
