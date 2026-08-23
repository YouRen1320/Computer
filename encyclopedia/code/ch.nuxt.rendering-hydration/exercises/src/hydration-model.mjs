// 故意错误：两侧随机值不同、服务端触碰浏览器 API，并把 secret 放入 payload。
export function buildHydrationEvidence() {
  return {
    serverHtml: '<p>seed-server</p>',
    clientFirstHtml: '<p>seed-client</p>',
    serverUsesBrowserApi: true,
    payload: { orders: [{ id: 'WO-101' }], internalToken: 'secret-token' },
  }
}

