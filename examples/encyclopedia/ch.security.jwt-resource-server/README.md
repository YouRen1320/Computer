# JWT Resource Server example

This offline Java example models the ordered trust decisions made by a JWT resource server. It deliberately uses synthetic evidence instead of real keys or compact bearer tokens: decoding is not authentication, and a request is accepted only after the token source, structure, algorithm, signature, issuer, audience, time window, type, and subject have all been checked.

Run `./verify.sh`. The verifier compiles with the local JDK, runs the deterministic scenario, and compares the output with `expected.out`. No network service, account, secret, or external dependency is required.

The example is an executable teaching model, not a replacement for Spring Security's cryptographic implementation. Production code should delegate parsing and signature verification to the configured Resource Server/JWT decoder and then apply current membership and business authorization checks.
