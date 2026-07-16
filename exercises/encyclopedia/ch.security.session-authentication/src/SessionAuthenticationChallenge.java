import java.time.Instant;
import java.util.List;

/** Starter for password metadata, reset, and Session lifecycle predicates. */
public final class SessionAuthenticationChallenge {
    enum CredentialKind { ADAPTIVE_ONE_WAY, NO_OP }

    record PasswordRecord(CredentialKind kind, String algorithm, String salt, int workFactor) { }
    record Session(int credentialVersion, boolean authenticated, boolean revoked) { }

    static final class ResetGrant {
        final String purpose;
        final Instant expiresAt;
        boolean consumed;

        ResetGrant(String purpose, Instant expiresAt) {
            this.purpose = purpose;
            this.expiresAt = expiresAt;
        }
    }

    private SessionAuthenticationChallenge() { }

    public static void main(String[] args) {
        PasswordRecord safe = new PasswordRecord(
                CredentialKind.ADAPTIVE_ONE_WAY, "ARGON2ID", "SALT-A", 3);
        PasswordRecord unsafe = new PasswordRecord(CredentialKind.NO_OP, "noop", "", 0);
        require(strongRecord(safe), "STRONG_PASSWORD_RECORD_REJECTED");
        require(!strongRecord(unsafe), "NOOP_PASSWORD_ACCEPTED");

        require(publicFailure(false, false).equals(publicFailure(true, false)),
                "ACCOUNT_ENUMERATION_VISIBLE");
        require(rotated("SYNTHETIC-PRE", "SYNTHETIC-AUTH"), "ROTATION_REJECTED");
        require(!rotated("SYNTHETIC-SAME", "SYNTHETIC-SAME"), "FIXATION_REUSE_ACCEPTED");

        Instant now = Instant.parse("2026-07-17T00:00:00Z");
        ResetGrant grant = new ResetGrant("PASSWORD_RESET", now.plusSeconds(60));
        require(consumeReset(grant, now), "VALID_RESET_REJECTED");
        require(!consumeReset(grant, now), "RESET_TOKEN_REPLAYED");

        require(sessionValid(new Session(2, true, false), 2), "VALID_SESSION_REJECTED");
        require(!sessionValid(new Session(1, true, false), 2), "OLD_CREDENTIAL_SESSION_ACCEPTED");
        require(!sessionValid(new Session(2, true, true), 2), "REVOKED_SESSION_ACCEPTED");
        require(withinConcurrentLimit(List.of(
                new Session(2, true, false), new Session(2, true, false)), 2, 2),
                "VALID_CONCURRENCY_REJECTED");
        require(!withinConcurrentLimit(List.of(
                new Session(2, true, false), new Session(2, true, false),
                new Session(2, true, false)), 2, 2), "CONCURRENT_LIMIT_BROKEN");

        System.out.println("challenge_valid=true password=true uniform=true rotation=true reset=true revocation=true concurrency=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean strongRecord(PasswordRecord record) {
        // TODO accept only a salted, named, adaptive one-way record with a positive cost.
        return true;
    }

    static String publicFailure(boolean accountExists, boolean passwordMatches) {
        // TODO return the same public failure for missing account and wrong password.
        return accountExists ? "BAD_PASSWORD" : "ACCOUNT_NOT_FOUND";
    }

    static boolean rotated(String preAuthId, String authenticatedId) {
        // TODO require nonblank and different identifiers.
        return true;
    }

    static boolean consumeReset(ResetGrant grant, Instant now) {
        // TODO atomically model correct purpose, strict expiry, and one-time consumption.
        return true;
    }

    static boolean sessionValid(Session session, int currentCredentialVersion) {
        // TODO require authenticated, non-revoked, current credential version.
        return true;
    }

    static boolean withinConcurrentLimit(List<Session> sessions, int currentVersion, int maximum) {
        // TODO count only active sessions of the current credential version.
        return true;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
