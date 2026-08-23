import { inject, provide } from 'vue'
import { repositoryKey, type WorkOrderRepository } from './contracts'

// Side effect: bind one implementation to the current component subtree.
export function provideRepository(repository: WorkOrderRepository) {
  provide(repositoryKey, repository)
}

export function requireRepository() {
  const repository = inject(repositoryKey)
  if (!repository) throw new Error('Missing WorkOrderRepository provider')
  return repository
}

