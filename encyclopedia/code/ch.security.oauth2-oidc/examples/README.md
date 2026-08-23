# OAuth/OIDC client-boundary example

This JDK 25 example is a deterministic model of one Authorization Code + PKCE/OIDC transaction. It proves exact `state`, `nonce`, redirect URI, PKCE, and one-time callback checks, then keeps Access, ID, and Refresh Token purposes separate.

Run `./verify.sh`. The example performs no HTTP request, discovery, cryptography, or provider login. All values are synthetic metadata; no usable authorization code, token, client secret, user, or account is present. Production integration must delegate protocol and signature work to Spring Security and a configured external OIDC Provider.
