import { readFile } from 'node:fs/promises'

// 职责：机械判定学习者发布证据包；只读取当前目录 fixture，不执行真实发布副作用。
const answer = JSON.parse(await readFile(new URL('./answer.json', import.meta.url), 'utf8'))
const { candidate, grayPlan, event } = answer
const problems = []
for (const key of ['productVersion', 'buildId', 'commit', 'artifactDigest', 'environment', 'apiOrigin']) if (!candidate[key]) problems.push(`candidate:${key}`)
if (candidate.environment === 'production' && candidate.apiOrigin.includes('localhost')) problems.push('candidate:production-localhost')
for (const key of ['buildId', 'scope', 'baseline', 'successCondition', 'stopCondition', 'rollbackCondition', 'decisionOwner', 'rollbackBuildId']) if (!grayPlan[key]) problems.push(`gray:${key}`)
if (grayPlan.buildId !== candidate.buildId || grayPlan.rollbackBuildId === candidate.buildId) problems.push('gray:version-link')
if (event.buildId !== candidate.buildId) problems.push('event:buildId')
for (const key of ['authorization', 'token', 'coordinates', 'description']) if (Object.hasOwn(event, key)) problems.push(`event:${key}`)
if (!answer.trialEvidence) problems.push('trial-evidence')
if (!answer.rollbackDrill) problems.push('rollback-drill')
if (problems.length) {
  console.error(`EXPECTED_UNIAPP_RELEASE_MONITORING_RED problems=${problems.join(',')}`)
  process.exit(1)
}
console.log('UNIAPP_RELEASE_MONITORING_EXERCISE_PASS')
