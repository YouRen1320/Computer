export type Priority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'

export type FormDraft = {
  assetId: string
  category: string
  description: string
  priority: Priority
  contact: string
  attachmentIds: string[]
}

export type CreateReportRequest = {
  assetId: string
  category: string
  description: string
  priority: Priority
  contact: string | null
  attachmentIds: string[]
}

// Data source: one default-value factory keeps input, reset, and test baselines identical.
export function emptyDraft(): FormDraft {
  return {
    assetId: '',
    category: '',
    description: '',
    priority: 'MEDIUM',
    contact: '',
    attachmentIds: [],
  }
}

// Mapping: whitelist the API contract and take an attachment snapshot at submit time.
export function toCreateReportRequest(draft: FormDraft): CreateReportRequest {
  return {
    assetId: draft.assetId,
    category: draft.category,
    description: draft.description,
    priority: draft.priority,
    contact: draft.contact === '' ? null : draft.contact,
    attachmentIds: [...draft.attachmentIds],
  }
}

