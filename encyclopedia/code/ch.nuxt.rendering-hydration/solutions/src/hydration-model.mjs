// 私有模型用同一 payload 驱动两侧首帧，且服务端路径不接触浏览器 API。
export function buildHydrationEvidence() {
  const payload = {
    seed: 'seed-2026-07-17',
    orders: [{ id: 'WO-101', title: '泵体温度异常' }],
  }
  const html = `<p>${payload.seed}:${payload.orders[0].title}</p>`
  return { serverHtml: html, clientFirstHtml: html, serverUsesBrowserApi: false, payload }
}

