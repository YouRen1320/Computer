import { ref } from 'vue'
import type { WorkOrderStatus } from '../src/contracts'

// Injected fault: module scope turns every call into an implicit global singleton.
const sharedStatus = ref<WorkOrderStatus>('CREATED')

export function useFaultySharedQueryState() {
  return { status: sharedStatus, setStatus: (next: WorkOrderStatus) => { sharedStatus.value = next } }
}

