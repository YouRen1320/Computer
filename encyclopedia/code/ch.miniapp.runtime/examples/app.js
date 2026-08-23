App({
  onLaunch(options) {
    // 应用职责：记录脱敏的宿主启动场景，不拥有页面查询状态。
    console.info('app:onLaunch', options?.scene ?? 'unknown')
  },
  onShow() {
    console.info('app:onShow')
  },
  onHide() {
    console.info('app:onHide')
  }
})
