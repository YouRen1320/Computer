import { readFile } from 'node:fs/promises'

// 职责：复用公开练习的稳定源码判据，证明维护答案可通过。
const html = await readFile(new URL('./index.html', import.meta.url), 'utf8')
const css = await readFile(new URL('./styles.css', import.meta.url), 'utf8')
const problems = []
if (/user-scalable=no|maximum-scale=1/.test(html)) problems.push('zoom-disabled')
if (!/width="\d+"[^>]*height="\d+"|height="\d+"[^>]*width="\d+"/.test(html)) problems.push('image-intrinsic-size')
if (!/sizes="\(min-width: 64rem\) 33vw, 100vw"/.test(html)) problems.push('sizes-slot')
if (/width:\s*1200px/.test(css)) problems.push('fixed-page-width')
if (/overflow-x:\s*hidden/.test(css)) problems.push('overflow-evidence-hidden')
if (!/clamp\(/.test(css)) problems.push('no-fluid-type-boundary')
if (!/@container/.test(css)) problems.push('no-container-adaptation')
if (problems.length) process.exit(1)
console.log('CSS_RESPONSIVE_TYPOGRAPHY_PRIVATE_PASS')
