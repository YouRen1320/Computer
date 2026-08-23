import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/** Offline authentication lifecycle model; all identifiers and credential metadata are synthetic. */
public final class SessionAuthenticationExample {
    enum CredentialKind { ADAPTIVE_ONE_WAY, NO_OP }

    record PasswordRecord(CredentialKind kind, String algorithmId, String saltId, int workFactor) { }

    static final class ResetGrant {
        final String purpose;
        final Instant expiresAt;
        boolean consumed;

        ResetGrant(String purpose, Instant expiresAt) {
            this.purpose = purpose;
            this.expiresAt = expiresAt;
        }
    }

    static final class SessionRecord {
        final String id;
        final int credentialVersion;
        boolean authenticated;
        boolean revoked;

        SessionRecord(String id, int credentialVersion, boolean authenticated) {
            this.id = id;
            this.credentialVersion = credentialVersion;
            this.authenticated = authenticated;
        }
    }

    static final class Account {
        int credentialVersion = 1;
        boolean enabled = true;
        final Map<String, SessionRecord> sessions = new LinkedHashMap<>();
    }

    static final class Engine {
        private final Account account = new Account();
        private int sequence;

        String anonymousSession() {
            String id = next("PREAUTH");
            account.sessions.put(id, new SessionRecord(id, account.credentialVersion, false));
            return id;
        }

        String login(String preAuthId, boolean credentialAccepted) {
            SessionRecord preAuth = account.sessions.get(preAuthId);
            if (!credentialAccepted || preAuth == null || preAuth.authenticated || preAuth.revoked) {
                throw new IllegalStateException("AUTHENTICATION_FAILED");
            }
            preAuth.revoked = true;
            String authenticatedId = next("AUTH");
            account.sessions.put(authenticatedId,
                    new SessionRecord(authenticatedId, account.credentialVersion, true));
            enforceConcurrentLimit(2);
            return authenticatedId;
        }

        boolean access(String sessionId) {
            SessionRecord session = account.sessions.get(sessionId);
            return account.enabled
                    && session != null
                    && session.authenticated
                    && !session.revoked
                    && session.credentialVersion == account.credentialVersion;
        }

        void changePassword() {
            account.credentialVersion++;
            account.sessions.values().forEach(session -> session.revoked = true);
        }

        void logout(String sessionId) {
            SessionRecord session = account.sessions.get(sessionId);
            if (session != null) {
                session.revoked = true;
            }
        }

        long activeSessions() {
            return account.sessions.values().stream().filter(this::active).count();
        }

        private void enforceConcurrentLimit(int maximum) {
            while (activeSessions() > maximum) {
                account.sessions.values().stream().filter(this::active).findFirst()
                        .orElseThrow().revoked = true;
            }
        }

        private boolean active(SessionRecord session) {
            return session.authenticated
                    && !session.revoked
                    && session.credentialVersion == account.credentialVersion;
        }

        private String next(String phase) {
            sequence++;
            return "SYNTHETIC-" + phase + "-SESSION-" + sequence;
        }
    }

    private SessionAuthenticationExample() { }

    public static void main(String[] args) {
        PasswordRecord record = new PasswordRecord(
                CredentialKind.ADAPTIVE_ONE_WAY, "ARGON2ID", "SYNTHETIC-SALT-A", 3);
        require(strongRecord(record), "WEAK_PASSWORD_RECORD_ACCEPTED");
        require(publicFailure(false, false).equals(publicFailure(true, false)),
                "ACCOUNT_ENUMERATION_RESPONSE_DIFFERENT");

        Engine engine = new Engine();
        String preAuth = engine.anonymousSession();
        String authenticated = engine.login(preAuth, true);
        require(!preAuth.equals(authenticated), "SESSION_ID_NOT_ROTATED");
        require(!engine.access(preAuth), "PREAUTH_SESSION_REUSED");
        require(engine.access(authenticated), "AUTHENTICATED_SESSION_REJECTED");

        Instant now = Instant.parse("2026-07-17T00:00:00Z");
        ResetGrant grant = new ResetGrant("PASSWORD_RESET", now.plusSeconds(300));
        require(consumeReset(grant, now), "VALID_RESET_REJECTED");
        require(!consumeReset(grant, now), "RESET_TOKEN_REPLAYED");

        engine.changePassword();
        require(!engine.access(authenticated), "OLD_SESSION_AFTER_PASSWORD_CHANGE");
        String afterChange = engine.login(engine.anonymousSession(), true);
        engine.logout(afterChange);
        require(!engine.access(afterChange), "LOGOUT_SESSION_REUSED");

        engine.login(engine.anonymousSession(), true);
        engine.login(engine.anonymousSession(), true);
        engine.login(engine.anonymousSession(), true);
        require(engine.activeSessions() == 2, "CONCURRENT_SESSION_LIMIT_BROKEN");

        System.out.println("password_record_strong=true");
        System.out.println("public_failure_uniform=true");
        System.out.println("login_rotated_id=true");
        System.out.println("preauth_rejected=true");
        System.out.println("reset_single_use=true");
        System.out.println("password_change_revoked_sessions=true");
        System.out.println("logout_invalidated=true");
        System.out.println("concurrent_limit_enforced=true");
        System.out.println("secret_material_printed=false");
    }

    static boolean strongRecord(PasswordRecord record) {
        return record.kind() == CredentialKind.ADAPTIVE_ONE_WAY
                && !record.algorithmId().isBlank()
                && !record.saltId().isBlank()
                && record.workFactor() > 1;
    }

    static String publicFailure(boolean accountExists, boolean passwordMatches) {
        return accountExists && passwordMatches ? "AUTHENTICATED" : "AUTHENTICATION_FAILED";
    }

    static boolean consumeReset(ResetGrant grant, Instant now) {
        if (!"PASSWORD_RESET".equals(grant.purpose)
                || grant.consumed
                || !now.isBefore(grant.expiresAt)) {
            return false;
        }
        grant.consumed = true;
        return true;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
