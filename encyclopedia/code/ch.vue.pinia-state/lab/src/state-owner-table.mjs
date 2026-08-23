// 所有权表是架构输入：每种状态只能有一个权威所有者和明确生命周期。
export const stateOwnerTable = [
  { name: 'reportDraft', kind: 'local', owner: 'ReportForm', lifetime: 'component' },
  { name: 'statusFilters', kind: 'shared-client', owner: 'workOrderViewStore', lifetime: 'session' },
  { name: 'activeFilterCount', kind: 'derived', owner: 'workOrderViewStore.getter', lifetime: 'derived' },
  { name: 'workOrderPage', kind: 'server', owner: 'query-cache', lifetime: 'cache-policy' },
]

