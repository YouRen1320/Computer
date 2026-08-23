import { createApp } from 'vue'
import App from './App.vue'

// 应用入口只负责把根组件挂到 index.html 的稳定宿主，不承载工单业务状态。
createApp(App).mount('#app')
