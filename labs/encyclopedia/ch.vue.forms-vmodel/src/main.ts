import { createApp } from 'vue'
import App from './App.vue'

// Side effect: mount only the corrected lab; the faulty component is test-only evidence.
createApp(App).mount('#app')

