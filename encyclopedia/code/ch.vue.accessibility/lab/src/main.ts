import { createApp } from 'vue'
import App from './App.vue'

// Important side effect: mount the lab once at its browser composition root.
createApp(App).mount('#app')
