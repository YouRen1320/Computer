import { inject, provide } from 'vue'
import { workOrderRepositoryKey, type WorkOrderRepository } from './contracts'

// Side effect: install the repository only for descendants in the current component subtree.
export function provideWorkOrderRepository(repository: WorkOrderRepository) {
  provide(workOrderRepositoryKey, repository)
}

export function requireWorkOrderRepository(): WorkOrderRepository {
  const repository = inject(workOrderRepositoryKey)
  if (!repository) {
    throw new Error('WorkOrderRepository provider is required')
  }
  return repository
}

