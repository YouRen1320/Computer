import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Responsibility: validate the submitted browser specification without claiming a browser execution.
const source = readFileSync(fileURLToPath(new URL('../e2e/login-work-order.spec.ts', import.meta.url)), 'utf8')
const roleLocators = (source.match(/getByRole\(/g) ?? []).length
const labelLocators = (source.match(/getByLabel\(/g) ?? []).length
const networkBoundary = (source.match(/page\.route\(/g) ?? []).length >= 2
const hasCriticalPath = /登录[\s\S]*工单查询[\s\S]*打开工单 WO-5001[\s\S]*工单详情 WO-5001/.test(source)
const brittle = /waitForTimeout\(|\.nth\(|locator\(['"][.#]/.test(source)

if (roleLocators < 3 || labelLocators < 2 || !networkBoundary || !hasCriticalPath || brittle) {
  console.error(`FAIL e2e-contract roles=${roleLocators} labels=${labelLocators} network=${networkBoundary} path=${hasCriticalPath} brittle=${brittle}`)
  process.exit(1)
}
console.log('PASS e2e-spec roles=yes network-boundary=yes fixed-sleep=no browser-run=UNVERIFIED')
