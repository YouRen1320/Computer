import { readFile } from 'node:fs/promises'

// Responsibility: mechanically classify submitted E2E and injected-fault evidence without launching a browser.
const good = await readFile(new URL('../e2e/login-work-order.spec.ts', import.meta.url), 'utf8')
const brittle = await readFile(new URL('../faults/brittle-login.spec.ts', import.meta.url), 'utf8')
const detail = await readFile(new URL('../faults/implementation-detail.test.ts', import.meta.url), 'utf8')
const missing = await readFile(new URL('../faults/missing-async-wait.test.ts', import.meta.url), 'utf8')
const overmocked = await readFile(new URL('../faults/overmocked-boundary.test.ts', import.meta.url), 'utf8')

const requiredGood = ['page.route(', 'getByLabel(', 'getByRole(', 'await expect(']
if (requiredGood.some((token) => !good.includes(token)) || /waitForTimeout|\.nth\(/.test(good)) throw new Error('healthy E2E contract is incomplete or brittle')
if (!/waitForTimeout/.test(brittle) || !/\.nth\(/.test(brittle)) throw new Error('brittle-selector fault is missing')
if (!detail.includes('wrapper.vm')) throw new Error('implementation-detail fault is missing')
if (missing.includes('flushPromises')) throw new Error('missing-wait fault accidentally waits')
if (!overmocked.includes('fakeChild')) throw new Error('overmocked-boundary fault is missing')
console.log('PASS evidence-boundaries good=role-label-network bad=detail-wait-overmock-selector')
