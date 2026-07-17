import { createPinia, defineStore, storeToRefs } from 'pinia'

// 该 store 只拥有跨组件的客户端筛选和布局偏好，不保存表单草稿或服务器工单。
export const useWorkOrderViewStore = defineStore('work-order-view', {
  state: () => ({
    statuses: [],
    assigneeId: null,
    compact: false,
  }),
  getters: {
    activeFilterCount: (state) =>
      state.statuses.length + Number(state.assigneeId !== null),
  },
  actions: {
    setStatuses(statuses) {
      this.statuses = [...new Set(statuses)]
    },
    setAssignee(assigneeId) {
      this.assigneeId = assigneeId
    },
    toggleCompact() {
      this.compact = !this.compact
    },
    resetForSessionBoundary() {
      this.$reset()
    },
  },
})

// 每次建立独立 Pinia 容器，使测试和会话边界不共享隐藏单例。
export function createViewHarness() {
  const pinia = createPinia()
  const filterPanel = useWorkOrderViewStore(pinia)
  const listPanel = useWorkOrderViewStore(pinia)
  const refs = storeToRefs(listPanel)
  return { pinia, filterPanel, listPanel, refs }
}

