// 三模式矩阵是 curl、Network 和水合 DOM 证据的共同预期。
export const matrix = [
  { mode: 'ssr', htmlHasData: true, serverFetches: 1, browserFetches: 0, hydrates: true },
  { mode: 'ssg', htmlHasData: true, serverFetches: 1, browserFetches: 0, hydrates: true },
  { mode: 'csr', htmlHasData: false, serverFetches: 0, browserFetches: 1, hydrates: false },
]

// 服务端与客户端首帧使用同一 seed、ISO 时间和 payload，确保确定性。
export function createHydrationSnapshot({ seed, isoTime, orders }) {
  const html = `<p data-seed="${seed}">${isoTime}:${orders.map((order) => order.id).join(',')}</p>`
  return { serverHtml: html, clientFirstHtml: html, payload: { seed, isoTime, orders } }
}

