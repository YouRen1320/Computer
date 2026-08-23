import { readFile } from 'node:fs/promises'

// 职责：让公开初始工件稳定红灯；不声称替代浏览器布局/视觉测试。
const html = await readFile(new URL('./index.html', import.meta.url), 'utf8')
const css = await readFile(new URL('./styles.css', import.meta.url), 'utf8')
const problems = []
if (/user-scalable=no|maximum-scale=1/.test(html)) problems.push('zoom-disabled')
if (!/width="\d+"[^>]*height="\d+"|height="\d+"[^>]*width="\d+"/.test(html)) problems.push('image-intrinsic-size')
if (/sizes="100vw"/.test(html)) problems.push('sizes-does-not-match-wide-slot')
if (/width:\s*1200px/.test(css)) problems.push('fixed-page-width')
if (/height:\s*32px/.test(css) && /overflow:\s*hidden/.test(css)) problems.push('text-clipping')
if (/overflow-x:\s*hidden/.test(css)) problems.push('overflow-evidence-hidden')
if (!/clamp\(/.test(css)) problems.push('no-fluid-type-boundary')
if (!/@container/.test(css)) problems.push('no-container-adaptation')
if (problems.length) {
  console.error(`EXPECTED_CSS_RESPONSIVE_TYPOGRAPHY_RED problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('CSS_RESPONSIVE_TYPOGRAPHY_EXERCISE_PASS')
