import { createApp } from 'vue'
import App from './App.vue'

// 入口仅安装根组件，避免把按需证据面板静态导入初始依赖图。
const app = createApp(App)
app.config.performance = import.meta.env.DEV
app.mount('#app')

