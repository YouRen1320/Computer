import { createApp } from 'vue'
import App from './App.vue'

// 入口的唯一副作用是把根组件挂到 HTML 已声明的 FactoryCare 宿主。
createApp(App).mount('#factorycare-root')
