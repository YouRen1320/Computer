import { buildHydrationEvidence } from '../src/hydration-model.mjs'

// 公共 oracle 同时检查确定性、运行时边界和 payload 白名单。
const evidence = buildHydrationEvidence()
const failures = []
if (evidence.serverHtml !== evidence.clientFirstHtml) failures.push('html-mismatch')
if (evidence.serverUsesBrowserApi) failures.push('browser-api-on-server')
if (/secret|token/i.test(JSON.stringify(evidence.payload))) failures.push('payload-secret')

if (failures.length > 0) {
  console.error(`HYDRATION_MISMATCH_EXERCISE: ${failures.join(',')}`)
  process.exit(1)
}

console.log('NUXT_RENDERING_HYDRATION_EXERCISE_PASS')

