// 私有参考模型用一个 store 作为生效筛选的唯一所有者。
export function createStateModel() {
  const state = {
    memberId: 101,
    statuses: ['ASSIGNED'],
  }

  return {
    state,
    get activeFilterCount() {
      return state.statuses.length
    },
    replaceStatuses(statuses) {
      state.statuses = [...new Set(statuses)]
    },
    resetForSessionBoundary() {
      state.memberId = null
      state.statuses = []
    },
  }
}

