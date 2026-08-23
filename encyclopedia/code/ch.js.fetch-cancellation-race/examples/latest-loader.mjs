// 职责：把 HTTP 响应分层、当前请求身份和取消传播集中在一个可测试边界。
export class HttpError extends Error {
  constructor(status, problem) {
    super(`HTTP_${status}`)
    this.name = 'HttpError'
    this.status = status
    this.problem = problem
  }
}

export async function parseJsonResponse(response) {
  // Mapping: Fetch 的 fulfilled Response 仍可能是 HTTP 失败，先检查 status 再交给业务。
  if (!response.ok) throw new HttpError(response.status, await response.readBody())
  return response.readBody()
}

export function deferred() {
  let resolve
  let reject
  const promise = new Promise((res, rej) => { resolve = res; reject = rej })
  return { promise, resolve, reject }
}

export function createLatestLoader(request) {
  let current = null
  const state = { items: [], loading: false, error: null }

  async function load(filter) {
    current?.controller.abort(new DOMException('superseded', 'AbortError'))
    const operation = { id: Symbol(filter), controller: new AbortController() }
    current = operation
    state.loading = true
    try {
      const items = await request(filter, { signal: operation.controller.signal })
      // Side effect: 只有仍为 current 的 operation 能提交共享 UI 状态。
      if (current === operation) {
        state.items = items
        state.error = null
      }
    } catch (error) {
      if (current === operation && !operation.controller.signal.aborted) state.error = error
    } finally {
      if (current === operation) state.loading = false
    }
  }

  return { state, load, cancel: () => current?.controller.abort(new DOMException('disposed', 'AbortError')) }
}

export async function retry(operation, { maxAttempts, shouldRetry, delay, sleep, signal }) {
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    signal?.throwIfAborted()
    try {
      return await operation(attempt)
    } catch (error) {
      if (!shouldRetry(error) || attempt + 1 >= maxAttempts) throw error
      await sleep(delay(attempt), { signal })
    }
  }
  throw new Error('UNREACHABLE_RETRY_STATE')
}
