import { expect, test } from '@playwright/test'

// Responsibility: cover one deployed-browser user path without importing Vue source or component instances.
test('login and open a work order', async ({ page }) => {
  await page.route('**/api/session', (route) => route.fulfill({ status: 200, json: { authenticated: true } }))
  await page.route('**/api/work-orders?status=CREATED', (route) => route.fulfill({
    status: 200,
    json: [{ id: 'WO-5001', title: '主轴振动复核', status: 'CREATED' }],
  }))

  await page.goto('/')
  await page.getByLabel('电子邮箱').fill('operator@example.test')
  await page.getByLabel('密码').fill('test-only-password')
  await page.getByRole('button', { name: '登录', exact: true }).click()
  await expect(page.getByRole('heading', { name: '工单查询' })).toBeVisible()
  await page.getByRole('button', { name: '打开工单 WO-5001' }).click()
  await expect(page.getByRole('heading', { name: '工单详情 WO-5001' })).toBeVisible()
})
