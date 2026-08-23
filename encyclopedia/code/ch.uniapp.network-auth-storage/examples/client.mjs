const ENDPOINTS = Object.freeze({
  development: 'https://dev-api.example.invalid',
  test: 'https://test-api.example.invalid',
  production: 'https://api.example.invalid'
})

export function apiBase(environment) {
  // 环境映射采用封闭允许列表，禁止 storage/query 注入任意 token 接收方。
  const value = ENDPOINTS[environment]
  if (!value) throw new Error('UNSUPPORTED_ENVIRONMENT')
  return value
}

export function mapHttp(response, parse) {
  // 传输成功后仍按 HTTP 和运行时 schema 分层映射。
  if (response.statusCode >= 200 && response.statusCode < 300) {
    try {
      return { kind: 'ok', value: parse(response.data) }
    } catch {
      return { kind: 'contract-error' }
    }
  }
  if (response.statusCode === 401) return { kind: 'unauthenticated' }
  if (response.statusCode === 403) return { kind: 'forbidden' }
  if (response.statusCode === 404) return { kind: 'not-found' }
  if (response.statusCode === 409) return { kind: 'conflict' }
  if (response.statusCode === 429) return { kind: 'rate-limited' }
  return { kind: 'server-error' }
}

export function mapTransport(error) {
  const code = String(error?.code ?? '')
  if (code === 'TIMEOUT') return { kind: 'transport-error', reason: 'timeout' }
  if (code === 'OFFLINE') return { kind: 'transport-error', reason: 'offline' }
  if (code === 'ABORTED') return { kind: 'transport-error', reason: 'cancelled' }
  return { kind: 'transport-error', reason: 'other' }
}

export function nextAuthState(current, event) {
  // 认证状态只描述本地候选凭据；服务端仍重建会员关系和权限。
  const key = `${current}:${event}`
  return ({
    'UNKNOWN:EMPTY': 'ANONYMOUS',
    'UNKNOWN:VALID': 'AUTHENTICATED',
    'AUTHENTICATED:HTTP_401': 'REFRESHING',
    'REFRESHING:REFRESH_OK': 'AUTHENTICATED',
    'REFRESHING:REFRESH_FAILED': 'EXPIRED',
    'AUTHENTICATED:REVOKED': 'REVOKED'
  })[key] ?? current
}

export function decodeDraft(raw, context) {
  // 本地缓存是不可信输入；版本、环境、用户与过期任何一项失败都拒绝。
  if (!raw || typeof raw !== 'object') return { kind: 'invalid', reason: 'shape' }
  if (raw.schemaVersion !== 1) return { kind: 'invalid', reason: 'version' }
  if (raw.environment !== context.environment) return { kind: 'invalid', reason: 'environment' }
  if (raw.subjectHash !== context.subjectHash) return { kind: 'invalid', reason: 'owner' }
  if (Date.parse(raw.expiresAt) <= context.nowEpochMs) return { kind: 'invalid', reason: 'expired' }
  if (!raw.payload || typeof raw.payload.description !== 'string') return { kind: 'invalid', reason: 'payload' }
  return { kind: 'ok', value: raw.payload }
}

export function safeLogFields(input) {
  // 字段允许列表比事后对任意对象做正则脱敏更容易证明。
  return {
    environment: String(input.environment),
    method: String(input.method),
    pathTemplate: String(input.pathTemplate),
    status: input.status == null ? undefined : Number(input.status),
    traceId: input.traceId == null ? undefined : String(input.traceId)
  }
}
