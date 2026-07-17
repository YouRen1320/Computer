import { createSSRApp } from 'vue'
import App from './App.vue'

export function createApp() {
  // 入口职责：创建根应用；页面发现来自 pages.json，不在这里复制路由表。
  const app = createSSRApp(App)
  return { app }
}
