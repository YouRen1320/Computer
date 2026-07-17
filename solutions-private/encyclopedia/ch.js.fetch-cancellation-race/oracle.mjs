import { readFile } from 'node:fs/promises'

// 职责：用公开练习相同规则验证私有可通过 fixture；没有网络副作用。
const a = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const problems = []
if (!a.checksHttpOk || a.responseBodyReads !== 1) problems.push('http-boundary')
if (!a.passesAbortSignal || !a.abortOnSupersede) problems.push('cancel')
if (!Object.values(a.commitGuards).every(Boolean)) problems.push('stale-guard')
if (a.retry.maxAttempts < 1 || a.retry.maxElapsedMs < 1 || a.retry.backoff === 'none' || !a.retry.jitter || a.retry.retryStatuses.includes(404)) problems.push('retry')
if (!Object.values(a.tests).every(Boolean)) problems.push('test-matrix')
if (problems.length) process.exit(1)
console.log('JS_FETCH_CANCELLATION_RACE_PRIVATE_PASS')
