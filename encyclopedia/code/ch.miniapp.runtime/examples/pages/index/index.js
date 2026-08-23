Page({
  onLoad() {
    console.info('index:onLoad')
  },
  onShow() {
    console.info('index:onShow')
  },
  onReady() {
    console.info('index:onReady')
  },
  onHide() {
    console.info('index:onHide')
  },
  onUnload() {
    console.info('index:onUnload')
  },
  openDetail() {
    // 路由副作用：只传稳定标识；详情页和服务端仍分别校验。
    wx.navigateTo({ url: '/pages/detail/detail?id=WO-1001' })
  }
})
