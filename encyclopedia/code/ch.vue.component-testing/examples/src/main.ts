import { createApp } from 'vue'
import App from './App.vue'

// Important side effect: create one browser app; component tests mount smaller public boundaries directly.
createApp(App).mount('#app')
