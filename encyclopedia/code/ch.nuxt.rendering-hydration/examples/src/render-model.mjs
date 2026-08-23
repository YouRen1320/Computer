const publicOrders = [
  { id: 'WO-101', title: '泵体温度异常' },
  { id: 'WO-102', title: '传送带异响' },
]

// 该模型固定 SSR/SSG/CSR 初始 HTML、payload 和浏览器请求数，供机械 oracle 对照。
export function renderRoute(mode) {
  if (mode === 'csr') {
    return {
      initialHtml: '<main><h1>CSR 工单</h1><p role="status">等待客户端数据</p></main>',
      payload: {},
      browserFetches: 1,
    }
  }

  const title = mode === 'ssr' ? 'SSR 工单' : 'SSG 工单'
  const items = publicOrders.map((order) => `<li>${order.title}</li>`).join('')
  return {
    initialHtml: `<main><h1>${title}</h1><ul>${items}</ul></main>`,
    payload: { [`work-orders:${mode}:v1`]: publicOrders },
    browserFetches: 0,
  }
}

