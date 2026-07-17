import { createApp } from 'vue'
import App from './App.vue'
import { router } from './router'

// Side effect: install browser history before mounting the lab app.
createApp(App).use(router).mount('#app')

