import { readFile } from 'node:fs/promises'

// 职责：让公开策略 fixture 稳定红灯；不把字段勾选当成真实浏览器/Vitest 证据。
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
if (!a.checksHttpOk) problems.push('http-status-not-checked')
if (a.responseBodyReads !== 1) problems.push('response-body-not-once')
if (!a.passesAbortSignal || !a.abortOnSupersede) problems.push('network-not-cancelled')
for (const key of ['items', 'error', 'loading']) if (!a.commitGuards[key]) problems.push(`stale-guard:${key}`)
if (a.retry.maxAttempts < 1 || a.retry.maxElapsedMs < 1 || a.retry.backoff === 'none' || !a.retry.jitter) problems.push('unbounded-retry-policy')
if (a.retry.retryStatuses.includes(404)) problems.push('retry-404')
for (const key of ['success', 'http404', 'parseError', 'timeout', 'abort', 'retryLimit', 'outOfOrder']) if (!a.tests[key]) problems.push(`test:${key}`)
if (problems.length) {
  console.error(`EXPECTED_JS_FETCH_CANCELLATION_RACE_RED problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('JS_FETCH_CANCELLATION_RACE_EXERCISE_PASS')
