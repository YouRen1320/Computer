import { defineConfig } from '@playwright/test'

// Responsibility: define the real-browser boundary; verify.sh intentionally does not invoke it.
export default defineConfig({
  testDir: './e2e',
  use: { baseURL: 'http://127.0.0.1:4173', trace: 'retain-on-failure' },
  retries: 0,
  workers: 1,
  webServer: {
    command: 'pnpm exec vite --host 127.0.0.1 --port 4173',
    url: 'http://127.0.0.1:4173',
    reuseExistingServer: false,
  },
})
