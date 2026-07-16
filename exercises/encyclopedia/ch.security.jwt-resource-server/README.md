# JWT validation challenge

Complete the seven `TODO` predicates in `src/JwtResourceServerChallenge.java`. The finished challenge must:

1. accept bearer credentials only from the Authorization header;
2. enforce a configured algorithm rather than trusting the token header;
3. require successful signature verification after decoding;
4. match both issuer and audience;
5. enforce `exp` and `nbf` at the supplied clock instant;
6. distinguish the access-token profile from another JWT type;
7. log only a diagnostic category and status, never the supplied compact-token marker.

Run `./verify.sh` before editing to confirm the intentionally red starter. Its first observable failure is `QUERY_BEARER_ACCEPTED`. Work locally with the synthetic values already supplied; no network, identity provider, key, account, or dependency download is needed.
