// Injected fault: it redirects even while already entering sign-in, creating the same target again.
export function faultyAuthenticationGuard(authenticated: boolean) {
  if (!authenticated) return { name: 'sign-in' as const }
  return true
}

