import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import javax.crypto.Mac;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;

/** Offline mechanism example; FactoryCare production delegates password handling to its external IdP. */
public final class PasswordStorageExample {
    private static final String ALGORITHM = "PBKDF2WithHmacSHA256";
    private static final int ITERATIONS = 600_000;
    private static final int KEY_BITS = 256;

    interface SaltSource { byte[] nextSalt(); }
    interface PepperVault { byte[] pepper(String pepperId); }

    static final class SecureRandomSaltSource implements SaltSource {
        private final SecureRandom random = new SecureRandom();

        @Override
        public byte[] nextSalt() {
            byte[] salt = new byte[16];
            random.nextBytes(salt);
            return salt;
        }
    }

    /** Deterministic salt injection is strictly a test seam, never a production source. */
    static final class TestOnlySaltSource implements SaltSource {
        private int index;

        @Override
        public byte[] nextSalt() {
            index++;
            byte[] salt = new byte[16];
            Arrays.fill(salt, (byte) index);
            return salt;
        }
    }

    static final class SyntheticPepperVault implements PepperVault {
        private final byte[] value = "SYNTHETIC_TRAINING_PEPPER_V1".getBytes(java.nio.charset.StandardCharsets.UTF_8);

        @Override
        public byte[] pepper(String pepperId) {
            if (!"pepper-v1".equals(pepperId)) {
                throw new IllegalArgumentException("UNKNOWN_PEPPER_ID");
            }
            return value.clone();
        }
    }

    static final class PasswordRecord {
        private final String algorithm;
        private final int iterations;
        private final byte[] salt;
        private final byte[] verifier;
        private final String pepperId;

        PasswordRecord(String algorithm, int iterations, byte[] salt, byte[] verifier, String pepperId) {
            this.algorithm = algorithm;
            this.iterations = iterations;
            this.salt = salt.clone();
            this.verifier = verifier.clone();
            this.pepperId = pepperId;
        }

        String algorithm() { return algorithm; }
        int iterations() { return iterations; }
        byte[] salt() { return salt.clone(); }
        byte[] verifier() { return verifier.clone(); }
        String pepperId() { return pepperId; }
    }

    static final class PepperedPbkdf2 {
        private final SaltSource salts;
        private final PepperVault peppers;

        PepperedPbkdf2(SaltSource salts, PepperVault peppers) {
            this.salts = salts;
            this.peppers = peppers;
        }

        PasswordRecord encode(char[] password) throws GeneralSecurityException {
            byte[] salt = salts.nextSalt();
            byte[] derived = derive(password, salt, ITERATIONS);
            byte[] pepper = peppers.pepper("pepper-v1");
            try {
                byte[] verifier = keyedVerifier(derived, pepper);
                return new PasswordRecord(ALGORITHM, ITERATIONS, salt, verifier, "pepper-v1");
            } finally {
                Arrays.fill(derived, (byte) 0);
                Arrays.fill(pepper, (byte) 0);
                Arrays.fill(salt, (byte) 0);
            }
        }

        boolean matches(char[] candidate, PasswordRecord record) throws GeneralSecurityException {
            byte[] salt = record.salt();
            byte[] derived = derive(candidate, salt, record.iterations());
            byte[] pepper = peppers.pepper(record.pepperId());
            byte[] expected = record.verifier();
            try {
                byte[] actual = keyedVerifier(derived, pepper);
                try {
                    return MessageDigest.isEqual(expected, actual);
                } finally {
                    Arrays.fill(actual, (byte) 0);
                }
            } finally {
                Arrays.fill(salt, (byte) 0);
                Arrays.fill(derived, (byte) 0);
                Arrays.fill(pepper, (byte) 0);
                Arrays.fill(expected, (byte) 0);
            }
        }

        private static byte[] derive(char[] password, byte[] salt, int iterations)
                throws GeneralSecurityException {
            PBEKeySpec spec = new PBEKeySpec(password, salt, iterations, KEY_BITS);
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

    private PasswordStorageExample() { }

    public static void main(String[] args) throws GeneralSecurityException {
        PepperedPbkdf2 encoder = new PepperedPbkdf2(new TestOnlySaltSource(), new SyntheticPepperVault());
        char[] password = "SYNTHETIC-TRAINING-PASSPHRASE-42".toCharArray();
        char[] wrong = "SYNTHETIC-TRAINING-PASSPHRASE-99".toCharArray();
        try {
            PasswordRecord first = encoder.encode(password);
            PasswordRecord second = encoder.encode(password);
            System.out.println("algorithm=" + first.algorithm());
            System.out.println("iterations=" + first.iterations());
            System.out.println("salt_bytes=" + first.salt().length);
            System.out.println("same_password_distinct_salt=" + !Arrays.equals(first.salt(), second.salt()));
            System.out.println("same_password_distinct_verifier=" + !Arrays.equals(first.verifier(), second.verifier()));
            System.out.println("correct_password_matches=" + encoder.matches(password, first));
            System.out.println("wrong_password_matches=" + encoder.matches(wrong, first));
            System.out.println("pepper_stored_with_record=false");
            System.out.println("secret_material_printed=false");
        } finally {
            Arrays.fill(password, '\0');
            Arrays.fill(wrong, '\0');
        }
    }
}
