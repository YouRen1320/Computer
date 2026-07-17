import { createApp } from 'vue'
import App from './App.vue'

// Side effect: browser mounting stays at the app boundary, not inside reusable logic.
createApp(App).mount('#app')

