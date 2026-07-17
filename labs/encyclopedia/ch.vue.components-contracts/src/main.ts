import { createApp } from 'vue'
import App from './App.vue'

// Side effect: mount only the corrected component graph; faults remain test-only.
createApp(App).mount('#app')

