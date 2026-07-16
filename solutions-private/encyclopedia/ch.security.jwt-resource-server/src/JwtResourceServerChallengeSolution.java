import java.time.Instant;
import java.util.Set;

/** Private reference solution for the ordered JWT resource-server validation gates. */
public final class JwtResourceServerChallengeSolution {
    enum TokenSource { AUTHORIZATION_HEADER, QUERY }

    private JwtResourceServerChallengeSolution() { }

    public static void main(String[] args) {
        Instant now = Instant.parse("2026-07-17T00:00:00Z");
        String issuer = "https://idp.factorycare.example.test/issuer";
        Set<String> audience = Set.of("factorycare-api");

        require(headerOnly(TokenSource.AUTHORIZATION_HEADER), "HEADER_BEARER_REJECTED");
        require(!headerOnly(TokenSource.QUERY), "QUERY_BEARER_ACCEPTED");
        require(allowedAlgorithm("RS256", "RS256"), "CONFIGURED_ALGORITHM_REJECTED");
        require(!allowedAlgorithm("none", "RS256"), "UNSUPPORTED_ALGORITHM_ACCEPTED");
        require(signatureAccepted(true, true), "VALID_SIGNATURE_REJECTED");
        require(!signatureAccepted(true, false), "UNVERIFIED_DECODE_ACCEPTED");
        require(issuerAudienceValid(issuer, issuer, audience, "factorycare-api"), "VALID_CLAIMS_REJECTED");
        require(!issuerAudienceValid("https://wrong.example.test", issuer, audience, "factorycare-api"),
                "WRONG_ISSUER_ACCEPTED");
        require(timeValid(now.plusSeconds(60), now.minusSeconds(1), now), "VALID_TIME_WINDOW_REJECTED");
        require(!timeValid(now.minusSeconds(1), now.minusSeconds(60), now), "EXPIRED_TOKEN_ACCEPTED");
        require(accessTokenProfile("at+jwt", "synthetic-technician"), "ACCESS_TOKEN_PROFILE_REJECTED");
        require(!accessTokenProfile("id+jwt", "synthetic-technician"), "WRONG_TOKEN_TYPE_ACCEPTED");

        String log = safeLog("signature", 401, "SYNTHETIC-COMPACT-TOKEN");
        require(!log.contains("SYNTHETIC-COMPACT-TOKEN"), "FULL_TOKEN_LOGGED");

        System.out.println("challenge_valid=true header=true algorithm=true signature=true claims=true time=true type=true logging=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean headerOnly(TokenSource source) {
        return source == TokenSource.AUTHORIZATION_HEADER;
    }

    static boolean allowedAlgorithm(String tokenAlgorithm, String configuredAlgorithm) {
        return configuredAlgorithm != null && configuredAlgorithm.equals(tokenAlgorithm);
    }

    static boolean signatureAccepted(boolean decoded, boolean signatureValid) {
        return decoded && signatureValid;
    }

    static boolean issuerAudienceValid(
            String tokenIssuer, String configuredIssuer, Set<String> audiences, String requiredAudience) {
        return configuredIssuer != null
                && configuredIssuer.equals(tokenIssuer)
                && audiences.contains(requiredAudience);
    }

    static boolean timeValid(Instant expiresAt, Instant notBefore, Instant now) {
        return now.isBefore(expiresAt) && !now.isBefore(notBefore);
    }

    static boolean accessTokenProfile(String type, String subject) {
        return "at+jwt".equals(type) && subject != null && !subject.isBlank();
    }

    static String safeLog(String category, int status, String compactToken) {
        return "jwt_validation=" + category + " status=" + status;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
