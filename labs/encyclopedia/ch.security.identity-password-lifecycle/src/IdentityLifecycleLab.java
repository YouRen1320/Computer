import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.crypto.Mac;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;

/** Deterministic identity lifecycle lab with synthetic credentials and explicit fault injection. */
public final class IdentityLifecycleLab {
    private static final String PUBLIC_AUTH_FAILURE = "AUTHENTICATION_FAILED";
    private static final String PUBLIC_RESET_RESULT = "IF_ELIGIBLE_INSTRUCTIONS_WILL_BE_SENT";

    enum AccountState { PENDING_VERIFICATION, ACTIVE, SUSPENDED, DISABLED }
    enum Purpose { VERIFY_ACCOUNT, RESET_PASSWORD }
    enum FaultMode { NONE, UNSAFE_STORAGE, FIXED_SALT, REPLAY_RESET, OLD_SESSION_SURVIVES }

    interface SaltSource { byte[] nextSalt(); }
    interface TokenSource { String nextToken(); }

    static final class SequenceSaltSource implements SaltSource {
        private final boolean fixed;
        private int sequence;

        SequenceSaltSource(boolean fixed) {
            this.fixed = fixed;
        }

        @Override
        public byte[] nextSalt() {
            byte[] value = new byte[16];
            Arrays.fill(value, (byte) (fixed ? 7 : ++sequence));
            return value;
        }
    }

    static final class SecureRandomSaltSource implements SaltSource {
        private final SecureRandom random = new SecureRandom();

        @Override
        public byte[] nextSalt() {
            byte[] value = new byte[16];
            random.nextBytes(value);
            return value;
        }
    }

    static final class TestOnlyTokenSource implements TokenSource {
        private int sequence;

        @Override
        public String nextToken() {
            sequence++;
            return "SYNTHETIC-ONE-TIME-TOKEN-000000000000000000000000-" + sequence;
        }
    }

    static final class SecureRandomTokenSource implements TokenSource {
        private final SecureRandom random = new SecureRandom();

        @Override
        public String nextToken() {
            byte[] value = new byte[32];
            random.nextBytes(value);
            return Base64.getUrlEncoder().withoutPadding().encodeToString(value);
        }
    }

    static final class MutableClock {
        private Instant now = Instant.parse("2026-07-17T00:00:00Z");

        Instant now() { return now; }
        void advance(Duration duration) { now = now.plus(duration); }
    }

    static final class PasswordRecord {
        private final String storageKind;
        private final String algorithm;
        private final int iterations;
        private final byte[] salt;
        private final byte[] verifier;
        private final String pepperId;

        PasswordRecord(String storageKind, String algorithm, int iterations,
                       byte[] salt, byte[] verifier, String pepperId) {
            this.storageKind = storageKind;
            this.algorithm = algorithm;
            this.iterations = iterations;
            this.salt = salt.clone();
            this.verifier = verifier.clone();
            this.pepperId = pepperId;
        }

        String storageKind() { return storageKind; }
        String algorithm() { return algorithm; }
        int iterations() { return iterations; }
        byte[] salt() { return salt.clone(); }
        byte[] verifier() { return verifier.clone(); }
        String pepperId() { return pepperId; }
    }

    static final class SafePasswordHasher {
        private static final String ALGORITHM = "PBKDF2WithHmacSHA256";
        private static final int ITERATIONS = 600_000;
        private final SaltSource salts;
        private final FaultMode faultMode;
        private final byte[] syntheticPepper =
                "SYNTHETIC_TRAINING_PEPPER_LAB_V1".getBytes(StandardCharsets.UTF_8);

        SafePasswordHasher(SaltSource salts, FaultMode faultMode) {
            this.salts = salts;
            this.faultMode = faultMode;
        }

        PasswordRecord encode(char[] password) throws GeneralSecurityException {
            byte[] salt = salts.nextSalt();
            byte[] derived = derive(password, salt, ITERATIONS);
            try {
                byte[] verifier = keyedVerifier(derived, syntheticPepper);
                String kind = faultMode == FaultMode.UNSAFE_STORAGE ? "REVERSIBLE" : "ADAPTIVE_ONE_WAY";
                return new PasswordRecord(kind, ALGORITHM, ITERATIONS, salt, verifier, "pepper-v1");
            } finally {
                Arrays.fill(salt, (byte) 0);
                Arrays.fill(derived, (byte) 0);
            }
        }

        boolean matches(char[] candidate, PasswordRecord record) throws GeneralSecurityException {
            if (!ALGORITHM.equals(record.algorithm()) || !"pepper-v1".equals(record.pepperId())) {
                return false;
            }
            byte[] salt = record.salt();
            byte[] derived = derive(candidate, salt, record.iterations());
            byte[] expected = record.verifier();
            try {
                byte[] actual = keyedVerifier(derived, syntheticPepper);
                try {
                    return MessageDigest.isEqual(expected, actual);
                } finally {
                    Arrays.fill(actual, (byte) 0);
                }
            } finally {
                Arrays.fill(salt, (byte) 0);
                Arrays.fill(derived, (byte) 0);
                Arrays.fill(expected, (byte) 0);
            }
        }

        private static byte[] derive(char[] password, byte[] salt, int iterations)
                throws GeneralSecurityException {
            PBEKeySpec spec = new PBEKeySpec(password, salt, iterations, 256);
            try {
                return SecretKeyFactory.getInstance(ALGORITHM).generateSecret(spec).getEncoded();
            } finally {
                spec.clearPassword();
            }
        }

        private static byte[] keyedVerifier(byte[] derived, byte[] pepper)
                throws GeneralSecurityException {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(pepper, "HmacSHA256"));
            return mac.doFinal(derived);
        }
    }

    static final class TokenRecord {
        final String digest;
        final String accountId;
        final Purpose purpose;
        final Instant expiresAt;
        boolean consumed;

        TokenRecord(String digest, String accountId, Purpose purpose, Instant expiresAt) {
            this.digest = digest;
            this.accountId = accountId;
            this.purpose = purpose;
            this.expiresAt = expiresAt;
        }
    }

    static final class SessionRecord {
        final String id;
        final int credentialVersion;
        boolean active = true;

        SessionRecord(String id, int credentialVersion) {
            this.id = id;
            this.credentialVersion = credentialVersion;
        }
    }

    static final class Account {
        final String id;
        final String login;
        AccountState state = AccountState.PENDING_VERIFICATION;
        PasswordRecord password;
        int credentialVersion = 1;
        int failedAttempts;
        Instant throttledUntil = Instant.EPOCH;
        String mfaFactorId;
        final Map<String, SessionRecord> sessions = new LinkedHashMap<>();

        Account(String id, String login, PasswordRecord password) {
            this.id = id;
            this.login = login;
            this.password = password;
        }
    }

    record AuditEvent(String event, String actor, String accountId, String result, String reason) { }

    static final class InMemoryDelivery {
        private final Map<Purpose, String> latest = new LinkedHashMap<>();

        void deliver(Purpose purpose, String syntheticRawToken) {
            latest.put(purpose, syntheticRawToken);
        }

        String latest(Purpose purpose) {
            String value = latest.get(purpose);
            if (value == null) {
                throw new IllegalStateException("NO_SYNTHETIC_DELIVERY:" + purpose);
            }
            return value;
        }
    }

    static final class IdentityService {
        private final SafePasswordHasher hasher;
        private final TokenSource tokens;
        private final MutableClock clock;
        private final FaultMode faultMode;
        private final InMemoryDelivery delivery = new InMemoryDelivery();
        private final Map<String, Account> byLogin = new LinkedHashMap<>();
        private final Map<String, Account> byId = new LinkedHashMap<>();
        private final Map<String, TokenRecord> tokenRecords = new LinkedHashMap<>();
        private final List<AuditEvent> audit = new ArrayList<>();
        private final PasswordRecord dummyRecord;
        private int accountSequence;
        private int sessionSequence;

        IdentityService(SafePasswordHasher hasher, TokenSource tokens, MutableClock clock,
                        FaultMode faultMode) throws GeneralSecurityException {
            this.hasher = hasher;
            this.tokens = tokens;
            this.clock = clock;
            this.faultMode = faultMode;
            char[] dummy = "SYNTHETIC-DUMMY-PASSPHRASE-000".toCharArray();
            try {
                this.dummyRecord = hasher.encode(dummy);
            } finally {
                Arrays.fill(dummy, '\0');
            }
        }

        String register(String login, char[] password) throws GeneralSecurityException {
            if (byLogin.containsKey(login)) {
                audit.add(new AuditEvent("registration", "ANONYMOUS", "UNKNOWN", "ACCEPTED", "DUPLICATE_HIDDEN"));
                return PUBLIC_RESET_RESULT;
            }
            String id = "ACCOUNT-" + ++accountSequence;
            Account account = new Account(id, login, hasher.encode(password));
            byLogin.put(login, account);
            byId.put(id, account);
            issue(account, Purpose.VERIFY_ACCOUNT, Duration.ofMinutes(15));
            audit.add(new AuditEvent("registration", "ANONYMOUS", id, "PENDING", "VERIFICATION_REQUIRED"));
            return PUBLIC_RESET_RESULT;
        }

        boolean verifyAccount(String rawToken) {
            TokenRecord token = usable(rawToken, Purpose.VERIFY_ACCOUNT);
            if (token == null) {
                return false;
            }
            token.consumed = true;
            Account account = byId.get(token.accountId);
            account.state = AccountState.ACTIVE;
            audit.add(new AuditEvent("account.verify", account.id, account.id, "SUCCESS", "TOKEN_CONSUMED"));
            return true;
        }

        String authenticate(String login, char[] candidate) throws GeneralSecurityException {
            Account account = byLogin.get(login);
            if (account == null) {
                hasher.matches(candidate, dummyRecord);
                audit.add(new AuditEvent("authentication", "ANONYMOUS", "UNKNOWN", "FAILURE", "ACCOUNT_NOT_FOUND"));
                return PUBLIC_AUTH_FAILURE;
            }
            if (clock.now().isBefore(account.throttledUntil)) {
                hasher.matches(candidate, dummyRecord);
                audit.add(new AuditEvent("authentication", account.id, account.id, "FAILURE", "THROTTLED"));
                return PUBLIC_AUTH_FAILURE;
            }
            if (account.state != AccountState.ACTIVE || !hasher.matches(candidate, account.password)) {
                account.failedAttempts++;
                if (account.failedAttempts >= 3) {
                    account.throttledUntil = clock.now().plusSeconds(30);
                }
                audit.add(new AuditEvent("authentication", account.id, account.id, "FAILURE", "INVALID_CREDENTIAL"));
                return PUBLIC_AUTH_FAILURE;
            }
            account.failedAttempts = 0;
            account.throttledUntil = Instant.EPOCH;
            String sessionId = "SESSION-" + ++sessionSequence;
            account.sessions.put(sessionId, new SessionRecord(sessionId, account.credentialVersion));
            audit.add(new AuditEvent("authentication", account.id, account.id, "SUCCESS", "SESSION_CREATED"));
            return sessionId;
        }

        String requestReset(String login) {
            Account account = byLogin.get(login);
            if (account != null && account.state == AccountState.ACTIVE) {
                issue(account, Purpose.RESET_PASSWORD, Duration.ofMinutes(15));
                audit.add(new AuditEvent("password.reset.request", "ANONYMOUS", account.id, "ACCEPTED", "DELIVERY_QUEUED"));
            } else {
                audit.add(new AuditEvent("password.reset.request", "ANONYMOUS", "UNKNOWN", "ACCEPTED", "INELIGIBLE_HIDDEN"));
            }
            return PUBLIC_RESET_RESULT;
        }

        boolean consumeReset(String rawToken, char[] newPassword) throws GeneralSecurityException {
            TokenRecord token = usable(rawToken, Purpose.RESET_PASSWORD);
            if (token == null) {
                return false;
            }
            token.consumed = true;
            Account account = byId.get(token.accountId);
            account.password = hasher.encode(newPassword);
            account.failedAttempts = 0;
            account.throttledUntil = Instant.EPOCH;
            if (faultMode != FaultMode.OLD_SESSION_SURVIVES) {
                account.credentialVersion++;
                account.sessions.values().forEach(session -> session.active = false);
            }
            tokenRecords.values().stream()
                    .filter(other -> other.accountId.equals(account.id) && other.purpose == Purpose.RESET_PASSWORD)
                    .forEach(other -> other.consumed = true);
            if (faultMode == FaultMode.REPLAY_RESET) {
                token.consumed = false;
            }
            audit.add(new AuditEvent("password.reset.consume", account.id, account.id, "SUCCESS", "CREDENTIAL_ROTATED"));
            return true;
        }

        boolean replaceMfa(String accountId, boolean reauthenticated, String newFactorId) {
            Account account = byId.get(accountId);
            if (account == null || account.state != AccountState.ACTIVE || !reauthenticated) {
                audit.add(new AuditEvent("mfa.replace", accountId, accountId, "DENIED", "REAUTH_REQUIRED"));
                return false;
            }
            account.mfaFactorId = newFactorId;
            account.credentialVersion++;
            account.sessions.values().forEach(session -> session.active = false);
            audit.add(new AuditEvent("mfa.replace", accountId, accountId, "SUCCESS", "FACTOR_REPLACED"));
            return true;
        }

        boolean adminRecover(String adminId, String accountId, boolean approved) {
            Account account = byId.get(accountId);
            if (account == null || !approved || adminId.equals(accountId)) {
                audit.add(new AuditEvent("admin.recovery", adminId, accountId, "DENIED", "APPROVAL_REQUIRED"));
                return false;
            }
            account.credentialVersion++;
            account.sessions.values().forEach(session -> session.active = false);
            audit.add(new AuditEvent("admin.recovery", adminId, accountId, "SUCCESS", "APPROVED_RECOVERY"));
            return true;
        }

        boolean sessionValid(String accountId, String sessionId) {
            Account account = byId.get(accountId);
            SessionRecord session = account.sessions.get(sessionId);
            return account.state == AccountState.ACTIVE
                    && session != null
                    && session.active
                    && session.credentialVersion == account.credentialVersion;
        }

        boolean isThrottled(String accountId) {
            return clock.now().isBefore(byId.get(accountId).throttledUntil);
        }

        Account account(String login) { return byLogin.get(login); }
        String delivered(Purpose purpose) { return delivery.latest(purpose); }
        List<AuditEvent> audit() { return List.copyOf(audit); }

        private void issue(Account account, Purpose purpose, Duration lifetime) {
            String raw = tokens.nextToken();
            String digest = digest(raw);
            tokenRecords.put(digest, new TokenRecord(digest, account.id, purpose, clock.now().plus(lifetime)));
            delivery.deliver(purpose, raw);
        }

        private TokenRecord usable(String raw, Purpose purpose) {
            TokenRecord token = tokenRecords.get(digest(raw));
            if (token == null || token.purpose != purpose || token.consumed
                    || !clock.now().isBefore(token.expiresAt)) {
                return null;
            }
            return token;
        }

        private static String digest(String raw) {
            try {
                byte[] value = MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8));
                return java.util.HexFormat.of().formatHex(value);
            } catch (GeneralSecurityException exception) {
                throw new IllegalStateException(exception);
            }
        }
    }

    private IdentityLifecycleLab() { }

    public static void main(String[] args) throws GeneralSecurityException {
        FaultMode mode = args.length == 0 ? FaultMode.NONE : FaultMode.valueOf(args[0]);
        MutableClock clock = new MutableClock();
        SaltSource salts = new SequenceSaltSource(mode == FaultMode.FIXED_SALT);
        SafePasswordHasher hasher = new SafePasswordHasher(salts, mode);
        IdentityService service = new IdentityService(hasher, new TestOnlyTokenSource(), clock, mode);
        String login = "learner@example.invalid";
        char[] oldPassword = "SYNTHETIC-OLD-PASSPHRASE-ONLY-42".toCharArray();
        char[] wrongPassword = "SYNTHETIC-WRONG-PASSPHRASE-ONLY-43".toCharArray();
        char[] newPassword = "SYNTHETIC-NEW-PASSPHRASE-ONLY-84".toCharArray();

        try {
            service.register(login, oldPassword);
            String verification = service.delivered(Purpose.VERIFY_ACCOUNT);
            require(service.verifyAccount(verification), "VERIFICATION_REJECTED");
            require(!service.verifyAccount(verification), "VERIFICATION_TOKEN_REPLAY_ACCEPTED");
            Account account = service.account(login);

            require("ADAPTIVE_ONE_WAY".equals(account.password.storageKind()), "PASSWORD_STORAGE_UNSAFE");
            PasswordRecord comparison = hasher.encode(oldPassword);
            require(!Arrays.equals(account.password.salt(), comparison.salt()), "SALT_REUSE_DETECTED");

            String oldSession = service.authenticate(login, oldPassword);
            require(!PUBLIC_AUTH_FAILURE.equals(oldSession), "VALID_PASSWORD_REJECTED");
            String knownFailure = service.authenticate(login, wrongPassword);
            String unknownFailure = service.authenticate("unknown@example.invalid", wrongPassword);
            require(knownFailure.equals(unknownFailure), "ACCOUNT_ENUMERATION_RESPONSE_DIFFERENT");
            service.authenticate(login, wrongPassword);
            service.authenticate(login, wrongPassword);
            require(service.isThrottled(account.id), "TEMPORARY_THROTTLE_MISSING");

            clock.advance(Duration.ofSeconds(31));
            String knownReset = service.requestReset(login);
            String unknownReset = service.requestReset("unknown@example.invalid");
            require(knownReset.equals(unknownReset), "RESET_ENUMERATION_RESPONSE_DIFFERENT");
            String expiredToken = service.delivered(Purpose.RESET_PASSWORD);
            clock.advance(Duration.ofMinutes(16));
            require(!service.consumeReset(expiredToken, newPassword), "EXPIRED_RESET_ACCEPTED");

            service.requestReset(login);
            String resetToken = service.delivered(Purpose.RESET_PASSWORD);
            require(service.consumeReset(resetToken, newPassword), "VALID_RESET_REJECTED");
            require(!service.consumeReset(resetToken, newPassword), "RESET_TOKEN_REPLAY_ACCEPTED");
            require(!service.sessionValid(account.id, oldSession), "OLD_SESSION_STILL_VALID");
            require(!hasher.matches(oldPassword, account.password), "OLD_PASSWORD_STILL_VALID");

            require(!service.replaceMfa(account.id, false, "SYNTHETIC-FACTOR-2"), "MFA_CHANGED_WITHOUT_REAUTH");
            require(service.replaceMfa(account.id, true, "SYNTHETIC-FACTOR-2"), "MFA_REAUTH_CHANGE_REJECTED");
            require(service.adminRecover("SYNTHETIC-ADMIN-1", account.id, true), "APPROVED_ADMIN_RECOVERY_REJECTED");
            require(auditSecretFree(service.audit(), List.of(verification, resetToken,
                    new String(oldPassword), new String(newPassword), "SYNTHETIC_TRAINING_PEPPER")),
                    "AUDIT_SECRET_LEAK");

            System.out.println("registration_verified=true");
            System.out.println("database_plaintext=false");
            System.out.println("same_password_distinct_salt=true");
            System.out.println("reset_expired=true");
            System.out.println("reset_single_use=true");
            System.out.println("old_session_revoked=true");
            System.out.println("old_password_rejected=true");
            System.out.println("enumeration_contract_equal=true");
            System.out.println("temporary_throttle=true");
            System.out.println("mfa_change_requires_reauth=true");
            System.out.println("admin_recovery_audited=true");
            System.out.println("audit_secret_free=true");
            System.out.println("verification_report=PASS assertions=17");
        } finally {
            Arrays.fill(oldPassword, '\0');
            Arrays.fill(wrongPassword, '\0');
            Arrays.fill(newPassword, '\0');
        }
    }

    static boolean auditSecretFree(List<AuditEvent> events, List<String> forbidden) {
        String rendered = events.toString();
        return forbidden.stream().noneMatch(rendered::contains);
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
