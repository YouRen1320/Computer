import { createApp } from 'vue'
import App from './App.vue'

// Side effect: mount the corrected lab model; injected faults remain test-only.
createApp(App).mount('#app')

