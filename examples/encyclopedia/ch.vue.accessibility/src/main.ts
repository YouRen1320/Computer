import { createApp } from 'vue'
import App from './App.vue'

// Important side effect: mount the accessible application once at the browser root.
createApp(App).mount('#app')
