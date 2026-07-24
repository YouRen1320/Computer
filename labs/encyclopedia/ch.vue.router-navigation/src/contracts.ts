export type Session = { authenticated: boolean; unsavedDetail: boolean }
export type Trace = Readonly<{ to: string; from: string; result: 'success' | 'failure'; type?: number }>
export type StatusFilter = 'ALL' | 'CREATED' | 'IN_PROGRESS' | 'RESOLVED'

// Mapping: query strings outside the FactoryCare status contract use an explicit non-filtering default.
export function normalizeStatus(value: unknown): StatusFilter {
  return value === 'CREATED' || value === 'IN_PROGRESS' || value === 'RESOLVED' ? value : 'ALL'
}

