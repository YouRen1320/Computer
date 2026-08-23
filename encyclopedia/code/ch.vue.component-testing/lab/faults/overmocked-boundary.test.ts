import { expect, it, vi } from 'vitest'

// Injected fault: replacing the whole child component proves only that a stub renders, not the real integration.
it('incorrectly treats a total child stub as product evidence', () => {
  const fakeChild = vi.fn(() => '<button>永远成功</button>')
  expect(fakeChild()).toContain('成功')
})
