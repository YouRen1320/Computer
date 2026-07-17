import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

// 职责：检查源码是否声明关键响应式合同；真实布局、视觉和资源选择刻意不在此模拟。
const html = await readFile(new URL('./index.html', import.meta.url), 'utf8')
const css = await readFile(new URL('./styles.css', import.meta.url), 'utf8')
assert.match(html, /width=device-width, initial-scale=1/)
assert.doesNotMatch(html, /user-scalable\s*=\s*no|maximum-scale\s*=\s*1/)
assert.match(html, /srcset=/)
assert.match(html, /sizes="\(min-width: 64rem\) 33vw, 100vw"/)
assert.match(html, /width="1440" height="960"/)
assert.match(css, /clamp\(/)
assert.match(css, /container:\s*work-order\s*\/\s*inline-size/)
assert.match(css, /@container\s+work-order/)
assert.match(css, /minmax\(0,\s*1fr\)/)
assert.match(css, /overflow-wrap:\s*anywhere/)
assert.doesNotMatch(css, /overflow-x:\s*hidden/)
console.log('CSS_RESPONSIVE_TYPOGRAPHY_EXAMPLE_PASS checks=11 evidence=offline-source-contract')
