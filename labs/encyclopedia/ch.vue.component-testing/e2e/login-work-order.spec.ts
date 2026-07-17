import { expect, test } from '@playwright/test'

// Responsibility: specify one genuine browser path with role/label locators and boundary-level network stubs.
test('login then open a work order', async ({ page }) => {
  await page.route('**/api/session', (route) => route.fulfill({ json: { displayName: '值班工程师' } }))
  await page.route('**/api/work-orders?status=CREATED', (route) => route.fulfill({ json: [{ id: 'WO-7001', title: '泵站复核', status: 'CREATED' }] }))
  await page.goto('/')
  await page.getByLabel('工号').fill('E-007')
  await page.getByRole('button', { name: '登录' }).click()
  await expect(page.getByRole('heading', { name: '工单查询实验' })).toBeVisible()
  await page.getByRole('button', { name: '打开工单 WO-7001' }).click()
  await expect(page.getByRole('heading', { name: '工单详情 WO-7001' })).toBeVisible()
})
