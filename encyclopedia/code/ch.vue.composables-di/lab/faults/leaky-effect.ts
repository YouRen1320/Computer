import { ref } from 'vue'

let activeSubscriptions = 0

// Injected fault: the effect increments ownership evidence but never registers onScopeDispose.
export function useFaultyLeakySubscription() {
  activeSubscriptions += 1
  return { ticks: ref(0) }
}

export function faultyActiveCount() { return activeSubscriptions }
export function resetFaultyActiveCount() { activeSubscriptions = 0 }

