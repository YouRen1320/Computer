// 服务端只返回公开 DTO；真实授权与租户隔离仍由 Java API 负责。
export default defineEventHandler(() => [
  { id: 'WO-101', title: '泵体温度异常' },
  { id: 'WO-102', title: '传送带异响' },
])

