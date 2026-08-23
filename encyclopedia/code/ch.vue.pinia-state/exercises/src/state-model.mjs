// 故意错误：localStatuses 与 store.statuses 都被当作生效筛选，形成双源状态。
export function createStateModel() {
  return {
    store: {
      memberId: 101,
      statuses: ['ASSIGNED'],
      activeFilterCount: 1,
    },
    localStatuses: ['IN_PROGRESS'],
    resetForSessionBoundary() {
      this.store.statuses = []
      // 故意遗漏 memberId、localStatuses 和复制的 activeFilterCount。
    },
  }
}

