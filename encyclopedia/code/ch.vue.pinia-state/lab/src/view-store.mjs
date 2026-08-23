import { createPinia, defineStore, storeToRefs } from 'pinia'

// Store 只管理跨组件客户端状态；reset 是显式会话边界。
const useViewStore = defineStore('lab-work-order-view', {
  state: () => ({ statuses: [], compact: false, memberId: null }),
  getters: {
    activeFilterCount: (state) => state.statuses.length,
  },
  actions: {
    replaceStatuses(statuses) {
      this.statuses = [...new Set(statuses)]
    },
    enterSession(memberId) {
      this.memberId = memberId
    },
    resetForSessionBoundary() {
      this.$reset()
    },
  },
})

// 返回两个消费者和 refs，供验证器观察同实例同步而不依赖浏览器。
export function createLabSession() {
  const pinia = createPinia()
  const filterPanel = useViewStore(pinia)
  const listPanel = useViewStore(pinia)
  return { filterPanel, listPanel, refs: storeToRefs(listPanel) }
}

