import { createApp } from 'vue'
import App from './App.vue'

// Important side effect: mount only at the browser composition root.
createApp(App).mount('#app')
