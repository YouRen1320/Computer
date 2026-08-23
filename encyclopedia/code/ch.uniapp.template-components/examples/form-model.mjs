export function normalizeRepairForm(form) {
  // UI 数据均视为不可信输入，只有成功解析后才形成业务命令。
  const deviceId = String(form.deviceId ?? '').trim()
  const description = String(form.description ?? '').trim()
  const priority = Number(form.priorityText)
  if (!/^DEV-[A-Z0-9-]{3,40}$/.test(deviceId)) return null
  if (description.length < 5 || description.length > 500) return null
  if (![1, 2, 3, 4, 5].includes(priority)) return null
  if (form.acceptedTerms !== true) return null
  return { deviceId, description, priority }
}
