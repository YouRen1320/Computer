import assert from 'node:assert/strict'
import { buildHydrationEvidence } from '../src/hydration-model.mjs'

// 私有 oracle 与公开练习保持相同确定性和安全判据。
const evidence = buildHydrationEvidence()
assert.equal(evidence.serverHtml, evidence.clientFirstHtml)
assert.equal(evidence.serverUsesBrowserApi, false)
assert.ok(!/secret|token/i.test(JSON.stringify(evidence.payload)))
assert.equal(JSON.parse(JSON.stringify(evidence.payload)).seed, 'seed-2026-07-17')

console.log('NUXT_RENDERING_HYDRATION_PRIVATE_PASS assertions=4')

