import { createApp } from 'vue'
import App from './App.vue'
import { router } from './router'

// Side effect: install the browser-history router before mounting the composition root.
createApp(App).use(router).mount('#app')

