import assert from 'node:assert/strict'
import { buildTarget, createPlatformServices } from './platform.mjs'

const h5Build = buildTarget('h5')
const mpBuild = buildTarget('mp-weixin')
assert.deepEqual(h5Build.includedModules, ['contracts', 'h5-adapter'])
assert.deepEqual(mpBuild.includedModules, ['contracts', 'weixin-adapter'])
assert.equal(h5Build.includedModules.includes('weixin-adapter'), false)
assert.equal(mpBuild.includedModules.includes('h5-adapter'), false)
assert.throws(() => buildTarget('MP-WEIXIN'), /UNKNOWN_BUILD_TARGET/)

const host = {
  // 数据源：脚本化宿主保证测试不依赖浏览器或微信全局对象。
  share: async () => 'ok',
  chooseFile: async () => ({ kind: 'ok', tempPath: 'fixture://repair.jpg' })
}

const h5 = createPlatformServices(h5Build, { target: 'h5', share: false, chooseFile: true }, host)
assert.deepEqual(await h5.shareWorkOrder({ id: 'WO-1001', title: '电机异响' }), {
  kind: 'unsupported', fallback: 'copy-link'
})
assert.deepEqual(await h5.chooseAttachment(), {
  kind: 'ok', value: { tempPath: 'fixture://repair.jpg' }
})

const mp = createPlatformServices(mpBuild, { target: 'mp-weixin', share: true, chooseFile: false }, host)
assert.deepEqual(await mp.shareWorkOrder({ id: 'WO-1002', title: '传送带停机' }), { kind: 'shared' })
assert.deepEqual(await mp.chooseAttachment(), {
  kind: 'unsupported', fallback: 'text-only-report'
})

const cancelHost = { ...host, share: async () => 'cancel' }
const mpCancel = createPlatformServices(mpBuild, { target: 'mp-weixin', share: true, chooseFile: true }, cancelHost)
assert.deepEqual(await mpCancel.shareWorkOrder({ id: 'WO-1003', title: '取消夹具' }), { kind: 'cancelled' })
assert.deepEqual(h5.calls.map((item) => item.adapter), ['h5-adapter', 'h5-adapter'])
assert.deepEqual(mp.calls.map((item) => item.adapter), ['weixin-adapter', 'weixin-adapter'])

console.log('UNIAPP_PLATFORM_CONDITIONAL_EXAMPLE_PASS checks=14 targets=2 evidence=offline-adapter-matrix')
