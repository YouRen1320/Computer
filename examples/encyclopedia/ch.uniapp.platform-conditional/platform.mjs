// 职责：提供与宿主无关的平台服务工厂，让页面只消费稳定领域结果。
const TARGETS = new Set(['h5', 'mp-weixin'])

export function buildTarget(target) {
  if (!TARGETS.has(target)) throw new Error(`UNKNOWN_BUILD_TARGET:${target}`)
  // 映射：真实条件编译应让每个产物只包含自己的 platformModule。
  return {
    target,
    platformModule: target === 'mp-weixin' ? 'weixin-adapter' : 'h5-adapter',
    includedModules: target === 'mp-weixin'
      ? ['contracts', 'weixin-adapter']
      : ['contracts', 'h5-adapter']
  }
}

export function createPlatformServices(build, capabilities, host) {
  if (build.target !== capabilities.target) throw new Error('TARGET_CAPABILITY_MISMATCH')
  const calls = []
  const record = (operation, outcome) => {
    // 副作用：只记录稳定分类与实现 id，不记录链接内容、凭据或宿主错误全文。
    calls.push({ target: build.target, adapter: build.platformModule, operation, outcome })
  }

  return {
    target: build.target,
    calls,
    async shareWorkOrder(input) {
      if (!/^WO-[0-9]+$/.test(input.id)) return { kind: 'failed', code: 'INVALID_WORK_ORDER', retryable: false }
      if (!capabilities.share) {
        record('share', 'unsupported')
        return { kind: 'unsupported', fallback: 'copy-link' }
      }
      const result = await host.share({ id: input.id, title: input.title })
      const mapped = result === 'ok'
        ? { kind: 'shared' }
        : result === 'cancel'
          ? { kind: 'cancelled' }
          : { kind: 'failed', code: 'HOST_SHARE_FAILED', retryable: true }
      record('share', mapped.kind)
      return mapped
    },
    async chooseAttachment() {
      if (!capabilities.chooseFile) {
        record('choose-file', 'unsupported')
        return { kind: 'unsupported', fallback: 'text-only-report' }
      }
      const result = await host.chooseFile()
      const mapped = result.kind === 'ok'
        ? { kind: 'ok', value: { tempPath: result.tempPath } }
        : result.kind === 'cancel'
          ? { kind: 'cancelled' }
          : { kind: 'failed', code: 'HOST_FILE_FAILED', retryable: true }
      record('choose-file', mapped.kind)
      return mapped
    }
  }
}
