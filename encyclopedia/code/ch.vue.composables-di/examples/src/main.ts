import { createApp } from 'vue'
import App from './App.vue'

// Side effect: create exactly one browser application at the HTML composition root.
createApp(App).mount('#app')

