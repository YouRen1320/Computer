import { createApp } from 'vue'
import App from './App.vue'

// 应用入口只挂载根组件，模板交互保留在 WorkOrderBoard 内。
createApp(App).mount('#app')
