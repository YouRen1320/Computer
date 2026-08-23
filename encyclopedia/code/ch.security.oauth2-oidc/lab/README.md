# OAuth/OIDC callback fault lab

This offline JDK 25 lab makes seven client-boundary failures observable: missing state, permissive redirect matching, skipped PKCE, skipped nonce, ID Token substitution at an API, Refresh Token exposure, and a static credential accepted for a public client.

Run `./verify.sh`. The normal policy must match `expected.out`; the verifier then injects each fault and requires its named oracle. The lab uses only fixed synthetic labels and never creates a real code, token, secret, browser callback, or provider request. Passing proves the decision model, not Spring Security or Provider interoperability.
