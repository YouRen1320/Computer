# JWT validation fault lab

This deterministic, offline lab treats a bearer token as untrusted evidence until an ordered validation chain succeeds. The normal run checks a valid request plus invalid signature, algorithm, issuer, audience, expiry, and query-parameter transport. It also proves that decoding alone does not authenticate and that the diagnostic log contains only a category.

Run `./verify.sh`. Besides the green-path comparison, the verifier injects seven faults one by one:

- trusting decoded data without verifying the signature;
- allowing the token to choose an unsupported algorithm;
- skipping issuer, audience, or time validation;
- accepting bearer credentials from the query string;
- writing a synthetic compact-token marker to a log line.

Each faulty execution must expose its named oracle. The source contains no real token, key, account, or network integration. The model teaches validation order; Spring Security remains responsible for production parsing and cryptography.
