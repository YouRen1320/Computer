import { createApp } from 'vue'
import App from './App.vue'

// Side effect: mount only the corrected lab; injected faults remain test-only.
createApp(App).mount('#app')

