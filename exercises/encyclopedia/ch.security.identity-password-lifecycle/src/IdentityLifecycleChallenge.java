import java.time.Instant;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;

/** Starter: lifecycle predicates use metadata only and never contain a real credential. */
public final class IdentityLifecycleChallenge {
    record StoredCredential(String storageKind, String algorithm, byte[] salt) {
        StoredCredential {
            salt = salt.clone();
        }

        @Override
        public byte[] salt() {
            return salt.clone();
        }
    }

    static final class ResetGrant {
        final String purpose;
        final Instant expiresAt;
        boolean consumed;

        ResetGrant(String purpose, Instant expiresAt) {
            this.purpose = purpose;
            this.expiresAt = expiresAt;
        }
    }

    static final class Account {
        int credentialVersion = 1;
        final Map<String, Integer> sessions = new LinkedHashMap<>();
    }

    private IdentityLifecycleChallenge() { }

    public static void main(String[] args) {
        StoredCredential safe = new StoredCredential("ADAPTIVE_ONE_WAY", "PBKDF2WithHmacSHA256", bytes(1));
        StoredCredential unsafe = new StoredCredential("REVERSIBLE", "AES", bytes(1));
        require(isSafeStorage(safe), "SAFE_STORAGE_REJECTED");
        require(!isSafeStorage(unsafe), "UNSAFE_STORAGE_ACCEPTED");
        require(distinctSalts(safe, new StoredCredential("ADAPTIVE_ONE_WAY", "PBKDF2WithHmacSHA256", bytes(2))),
                "DISTINCT_SALTS_REJECTED");
        require(!distinctSalts(safe, new StoredCredential("ADAPTIVE_ONE_WAY", "PBKDF2WithHmacSHA256", bytes(1))),
                "REUSED_SALT_ACCEPTED");

        Instant now = Instant.parse("2026-07-17T00:00:00Z");
        ResetGrant grant = new ResetGrant("RESET_PASSWORD", now.plusSeconds(60));
        require(resetUsable(grant, now), "VALID_RESET_REJECTED");
        grant.consumed = true;
        require(!resetUsable(grant, now), "RESET_REPLAY_ACCEPTED");
        require(!resetUsable(new ResetGrant("RESET_PASSWORD", now), now), "EXPIRED_RESET_ACCEPTED");

        require(publicResetResponse(true).equals(publicResetResponse(false)), "ACCOUNT_ENUMERATION_RESPONSE_DIFFERENT");
        Account account = new Account();
        account.sessions.put("SESSION-OLD", account.credentialVersion);
        rotateAndRevoke(account);
        require(account.credentialVersion == 2, "CREDENTIAL_VERSION_NOT_ROTATED");
        require(!sessionValid(account, "SESSION-OLD"), "OLD_SESSION_STILL_VALID");
        require(!canReplaceMfa(false) && canReplaceMfa(true), "MFA_REAUTH_BOUNDARY_BROKEN");

        System.out.println("challenge_valid=true storage=true token_once=true rotation=true enumeration=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean isSafeStorage(StoredCredential credential) {
        // TODO accept only an adaptive one-way record with a named algorithm and non-empty salt.
        return true;
    }

    static boolean distinctSalts(StoredCredential first, StoredCredential second) {
        // TODO prove two records do not reuse the same salt bytes.
        return true;
    }

    static boolean resetUsable(ResetGrant grant, Instant now) {
        // TODO require the correct purpose, an unconsumed grant, and now strictly before expiry.
        return true;
    }

    static String publicResetResponse(boolean accountExists) {
        // TODO return the same public contract regardless of account existence.
        return accountExists ? "RESET_SENT" : "ACCOUNT_NOT_FOUND";
    }

    static void rotateAndRevoke(Account account) {
        // TODO increment the credential version and revoke every old session.
    }

    static boolean sessionValid(Account account, String sessionId) {
        Integer version = account.sessions.get(sessionId);
        return version != null && version == account.credentialVersion;
    }

    static boolean canReplaceMfa(boolean reauthenticated) {
        return reauthenticated;
    }

    private static byte[] bytes(int value) {
        byte[] result = new byte[16];
        Arrays.fill(result, (byte) value);
        return result;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
