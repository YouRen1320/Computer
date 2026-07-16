import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/** Offline fault injection for password, reset, login, logout, and concurrent Session boundaries. */
public final class SessionAuthenticationLab {
    enum FaultMode {
        NONE, NOOP_PASSWORD, RESET_REPLAY, OLD_SESSION_AFTER_PASSWORD_CHANGE,
        FIXATION_REUSE, ACCOUNT_ENUMERATION, LOGOUT_CLIENT_ONLY, CONCURRENT_LIMIT_BROKEN
    }

    enum CredentialKind { ADAPTIVE_ONE_WAY, NO_OP }

    record PasswordRecord(CredentialKind kind, String algorithm, String salt, int workFactor) { }

    static final class ResetGrant {
        final Instant expiresAt;
        boolean consumed;

        ResetGrant(Instant expiresAt) {
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

    static final class Engine {
        private final FaultMode mode;
        private final Map<String, SessionRecord> sessions = new LinkedHashMap<>();
        private int credentialVersion = 1;
        private int sequence;

        Engine(FaultMode mode) {
            this.mode = mode;
        }

        String anonymous() {
            String id = next("PRE");
            sessions.put(id, new SessionRecord(id, credentialVersion, false));
            return id;
        }

        String login(String preAuthId) {
            SessionRecord pre = sessions.get(preAuthId);
            if (pre == null || pre.authenticated || pre.revoked) {
                throw new IllegalStateException("PREAUTH_INVALID");
            }
            if (mode == FaultMode.FIXATION_REUSE) {
                pre.authenticated = true;
                return preAuthId;
            }
            pre.revoked = true;
            String id = next("AUTH");
            sessions.put(id, new SessionRecord(id, credentialVersion, true));
            enforceMaximum(2);
            return id;
        }

        boolean access(String id) {
            SessionRecord session = sessions.get(id);
            if (session == null || !session.authenticated || session.revoked) {
                return false;
            }
            return mode == FaultMode.OLD_SESSION_AFTER_PASSWORD_CHANGE
                    || session.credentialVersion == credentialVersion;
        }

        void passwordChanged() {
            if (mode == FaultMode.OLD_SESSION_AFTER_PASSWORD_CHANGE) {
                return;
            }
            credentialVersion++;
            sessions.values().forEach(session -> session.revoked = true);
        }

        void logout(String id) {
            if (mode == FaultMode.LOGOUT_CLIENT_ONLY) {
                return;
            }
            SessionRecord session = sessions.get(id);
            if (session != null) {
                session.revoked = true;
            }
        }

        long activeCount() {
            return sessions.values().stream()
                    .filter(session -> session.authenticated && !session.revoked
                            && session.credentialVersion == credentialVersion)
                    .count();
        }

        private void enforceMaximum(int maximum) {
            if (mode == FaultMode.CONCURRENT_LIMIT_BROKEN) {
                return;
            }
            while (activeCount() > maximum) {
                sessions.values().stream()
                        .filter(session -> session.authenticated && !session.revoked
                                && session.credentialVersion == credentialVersion)
                        .findFirst().orElseThrow().revoked = true;
            }
        }

        private String next(String phase) {
            sequence++;
            return "SYNTHETIC-" + phase + "-SESSION-" + sequence;
        }
    }

    private SessionAuthenticationLab() { }

    public static void main(String[] args) {
        FaultMode mode = args.length == 0 ? FaultMode.NONE : FaultMode.valueOf(args[0]);
        PasswordRecord password = mode == FaultMode.NOOP_PASSWORD
                ? new PasswordRecord(CredentialKind.NO_OP, "noop", "", 0)
                : new PasswordRecord(CredentialKind.ADAPTIVE_ONE_WAY, "ARGON2ID", "SALT-A", 3);
        require(strongRecord(password), "NOOP_PASSWORD_ACCEPTED");

        require(publicFailure(mode, false, false).equals(publicFailure(mode, true, false)),
                "ACCOUNT_ENUMERATION_VISIBLE");

        Engine engine = new Engine(mode);
        String preAuth = engine.anonymous();
        String authenticated = engine.login(preAuth);
        require(!preAuth.equals(authenticated), "SESSION_FIXATION_REUSED_ID");
        require(!engine.access(preAuth), "PREAUTH_SESSION_REUSABLE");
        require(engine.access(authenticated), "AUTHENTICATED_SESSION_REJECTED");

        Instant now = Instant.parse("2026-07-17T00:00:00Z");
        ResetGrant reset = new ResetGrant(now.plusSeconds(60));
        require(consumeReset(mode, reset, now), "VALID_RESET_REJECTED");
        require(!consumeReset(mode, reset, now), "RESET_TOKEN_REPLAYED");

        engine.passwordChanged();
        require(!engine.access(authenticated), "OLD_SESSION_AFTER_PASSWORD_CHANGE");
        String afterChange = engine.login(engine.anonymous());
        engine.logout(afterChange);
        require(!engine.access(afterChange), "LOGOUT_SERVER_STATE_STILL_VALID");

        engine.login(engine.anonymous());
        engine.login(engine.anonymous());
        engine.login(engine.anonymous());
        require(engine.activeCount() == 2, "CONCURRENT_SESSION_LIMIT_BROKEN");

        System.out.println("password_storage=ADAPTIVE_ONE_WAY");
        System.out.println("failure_contract=UNIFORM");
        System.out.println("session_rotation=true");
        System.out.println("reset_single_use=true");
        System.out.println("credential_version_revocation=true");
        System.out.println("logout_server_invalidation=true");
        System.out.println("concurrent_sessions=2");
        System.out.println("verification_report=PASS assertions=9");
    }

    static boolean strongRecord(PasswordRecord record) {
        return record.kind() == CredentialKind.ADAPTIVE_ONE_WAY
                && !record.algorithm().isBlank()
                && !record.salt().isBlank()
                && record.workFactor() > 1;
    }

    static String publicFailure(FaultMode mode, boolean accountExists, boolean matches) {
        if (mode == FaultMode.ACCOUNT_ENUMERATION) {
            return accountExists ? "BAD_PASSWORD" : "ACCOUNT_NOT_FOUND";
        }
        return accountExists && matches ? "AUTHENTICATED" : "AUTHENTICATION_FAILED";
    }

    static boolean consumeReset(FaultMode mode, ResetGrant grant, Instant now) {
        if (!now.isBefore(grant.expiresAt)) {
            return false;
        }
        if (mode == FaultMode.RESET_REPLAY) {
            return true;
        }
        if (grant.consumed) {
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
