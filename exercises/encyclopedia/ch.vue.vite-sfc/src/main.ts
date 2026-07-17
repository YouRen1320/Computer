import { createApp } from 'vue'
import App from './App.vue'

// TODO：入口只负责挂载；修复选择器，使它与 index.html 的既有宿主契约一致。
createApp(App).mount('#app')
