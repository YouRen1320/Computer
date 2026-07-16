# Private solution: JWT validation challenge

This private reference completes the seven validation predicates from the public exercise. It stays deliberately independent of a JWT library so the trust decisions remain visible: transport, configured algorithm, verified signature, issuer/audience, time window, token profile, and safe diagnostics.

Run `./verify.sh` for a deterministic green result. The implementation uses only synthetic metadata and a fixed clock. It performs no cryptography, makes no network request, and contains no usable bearer token or key; a production Resource Server must delegate cryptographic work to Spring Security and its configured decoder.
