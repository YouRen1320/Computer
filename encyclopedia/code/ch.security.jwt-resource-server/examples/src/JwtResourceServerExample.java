import java.time.Instant;
import java.util.Set;

/** Demonstrates the trust gates a resource server must complete before authentication. */
public final class JwtResourceServerExample {
    private static final Instant NOW = Instant.parse("2026-07-17T00:00:00Z");
    private static final String ISSUER = "https://idp.factorycare.example.test/issuer";
    private static final String AUDIENCE = "factorycare-api";

    private enum TokenSource { AUTHORIZATION_HEADER, QUERY }

    private record TokenEvidence(
            TokenSource source,
            int segments,
            boolean decoded,
            String algorithm,
            boolean signatureValid,
            String issuer,
            Set<String> audiences,
            Instant expiresAt,
            Instant notBefore,
            String type,
            String subject) {
    }

    private record Result(int status, String category, boolean authenticated) {
    }

    private static Result validate(TokenEvidence token) {
        if (token.source() != TokenSource.AUTHORIZATION_HEADER) {
            return rejected("token_source");
        }
        if (token.segments() != 3 || !token.decoded()) {
            return rejected("structure");
        }
        if (!"RS256".equals(token.algorithm())) {
            return rejected("algorithm");
        }
        if (!token.signatureValid()) {
            return rejected("signature");
        }
        if (!ISSUER.equals(token.issuer())) {
            return rejected("issuer");
        }
        if (!token.audiences().contains(AUDIENCE)) {
            return rejected("audience");
        }
        if (!NOW.isBefore(token.expiresAt()) || NOW.isBefore(token.notBefore())) {
            return rejected("time_window");
        }
        if (!"at+jwt".equals(token.type()) || token.subject().isBlank()) {
            return rejected("token_profile");
        }
        return new Result(200, "accepted", true);
    }

    private static Result rejected(String category) {
        return new Result(401, category, false);
    }

    private static TokenEvidence validToken() {
        return new TokenEvidence(
                TokenSource.AUTHORIZATION_HEADER,
                3,
                true,
                "RS256",
                true,
                ISSUER,
                Set.of(AUDIENCE),
                NOW.plusSeconds(300),
                NOW.minusSeconds(10),
                "at+jwt",
                "synthetic-technician");
    }

    private static TokenEvidence with(
            TokenEvidence token,
            TokenSource source,
            boolean signatureValid,
            String issuer,
            Set<String> audiences,
            Instant expiresAt) {
        return new TokenEvidence(
                source,
                token.segments(),
                token.decoded(),
                token.algorithm(),
                signatureValid,
                issuer,
                audiences,
                expiresAt,
                token.notBefore(),
                token.type(),
                token.subject());
    }

    private static String safeLog(Result result) {
        return "jwt_validation=" + result.category() + " status=" + result.status();
    }

    public static void main(String[] args) {
        TokenEvidence valid = validToken();
        Result accepted = validate(valid);
        Result forged = validate(with(valid, valid.source(), false, ISSUER, valid.audiences(), valid.expiresAt()));
        Result expired = validate(with(valid, valid.source(), true, ISSUER, valid.audiences(), NOW.minusSeconds(1)));
        Result wrongAudience = validate(with(valid, valid.source(), true, ISSUER, Set.of("another-api"), valid.expiresAt()));
        Result wrongIssuer = validate(with(valid, valid.source(), true, "https://wrong.example.test", valid.audiences(), valid.expiresAt()));
        Result query = validate(with(valid, TokenSource.QUERY, true, ISSUER, valid.audiences(), valid.expiresAt()));
        String auditLine = safeLog(forged);

        System.out.println("valid_token_status=" + accepted.status());
        System.out.println("forged_signature_status=" + forged.status());
        System.out.println("expired_token_status=" + expired.status());
        System.out.println("wrong_audience_status=" + wrongAudience.status());
        System.out.println("wrong_issuer_status=" + wrongIssuer.status());
        System.out.println("query_bearer_status=" + query.status());
        System.out.println("decoded_only_authenticated=" + forged.authenticated());
        System.out.println("full_token_logged=" + auditLine.contains("compact-token"));
        System.out.println("secret_material_printed=false");
    }
}
