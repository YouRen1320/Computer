Page({
  data: { id: '' },
  onLoad(options) {
    // 数据来源：路由 query；只接受 FactoryCare 示例 ID 形状。
    const id = String(options?.id ?? '')
    this.setData({ id: /^WO-[0-9]+$/.test(id) ? id : 'INVALID' })
    console.info('detail:onLoad')
  },
  onShow() {
    console.info('detail:onShow')
  },
  onReady() {
    console.info('detail:onReady')
  },
  onHide() {
    console.info('detail:onHide')
  },
  onUnload() {
    console.info('detail:onUnload')
  },
  browserDomAvailability() {
    // 小程序逻辑层不把浏览器 DOM 作为公开宿主合同。
    return typeof document
  }
})
