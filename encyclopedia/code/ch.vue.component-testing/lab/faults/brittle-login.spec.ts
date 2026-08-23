import { test, expect } from '@playwright/test'

// Injected fault: positional selection and fixed sleep turn timing/layout drift into flakiness.
test('brittle work-order opening', async ({ page }) => {
  await page.goto('/')
  await page.waitForTimeout(1000)
  await page.locator('button').nth(2).click()
  await expect(page.locator('h2').nth(0)).toBeVisible()
})
