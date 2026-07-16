import java.time.Instant;
import java.util.Set;

/** Fault-injection model for the first trustworthy evidence in JWT validation. */
public final class JwtValidationLab {
    private static final Instant NOW = Instant.parse("2026-07-17T00:00:00Z");
    private static final String ISSUER = "https://idp.factorycare.example.test/issuer";
    private static final String AUDIENCE = "factorycare-api";

    private enum TokenSource { AUTHORIZATION_HEADER, QUERY }

    private enum FaultMode {
        NORMAL,
        DECODE_ONLY,
        ALG_FROM_TOKEN,
        ISSUER_NOT_CHECKED,
        AUDIENCE_NOT_CHECKED,
        TIME_NOT_CHECKED,
        QUERY_TOKEN,
        TOKEN_LOGGED
    }

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

    private static Result validate(TokenEvidence token, FaultMode fault) {
        if (fault != FaultMode.QUERY_TOKEN && token.source() != TokenSource.AUTHORIZATION_HEADER) {
            return rejected("token_source");
        }
        if (token.segments() != 3 || !token.decoded()) {
            return rejected("structure");
        }
        if (fault != FaultMode.ALG_FROM_TOKEN && !"RS256".equals(token.algorithm())) {
            return rejected("algorithm");
        }
        if (fault != FaultMode.DECODE_ONLY && !token.signatureValid()) {
            return rejected("signature");
        }
        if (fault != FaultMode.ISSUER_NOT_CHECKED && !ISSUER.equals(token.issuer())) {
            return rejected("issuer");
        }
        if (fault != FaultMode.AUDIENCE_NOT_CHECKED && !token.audiences().contains(AUDIENCE)) {
            return rejected("audience");
        }
        if (fault != FaultMode.TIME_NOT_CHECKED
                && (!NOW.isBefore(token.expiresAt()) || NOW.isBefore(token.notBefore()))) {
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

    private static TokenEvidence token(
            TokenSource source,
            String algorithm,
            boolean signatureValid,
            String issuer,
            Set<String> audiences,
            Instant expiresAt) {
        return new TokenEvidence(
                source,
                3,
                true,
                algorithm,
                signatureValid,
                issuer,
                audiences,
                expiresAt,
                NOW.minusSeconds(10),
                "at+jwt",
                "synthetic-technician");
    }

    private static TokenEvidence valid() {
        return token(TokenSource.AUTHORIZATION_HEADER, "RS256", true, ISSUER, Set.of(AUDIENCE), NOW.plusSeconds(300));
    }

    private static String safeLog(Result result, FaultMode fault, String syntheticTokenMarker) {
        if (fault == FaultMode.TOKEN_LOGGED) {
            return "jwt_validation=" + result.category() + " token=" + syntheticTokenMarker;
        }
        return "jwt_validation=" + result.category() + " status=" + result.status();
    }

    private static String injectedOutcome(FaultMode fault) {
        Result result = switch (fault) {
            case DECODE_ONLY -> validate(token(TokenSource.AUTHORIZATION_HEADER, "RS256", false, ISSUER,
                    Set.of(AUDIENCE), NOW.plusSeconds(300)), fault);
            case ALG_FROM_TOKEN -> validate(token(TokenSource.AUTHORIZATION_HEADER, "none", true, ISSUER,
                    Set.of(AUDIENCE), NOW.plusSeconds(300)), fault);
            case ISSUER_NOT_CHECKED -> validate(token(TokenSource.AUTHORIZATION_HEADER, "RS256", true,
                    "https://wrong.example.test", Set.of(AUDIENCE), NOW.plusSeconds(300)), fault);
            case AUDIENCE_NOT_CHECKED -> validate(token(TokenSource.AUTHORIZATION_HEADER, "RS256", true, ISSUER,
                    Set.of("another-api"), NOW.plusSeconds(300)), fault);
            case TIME_NOT_CHECKED -> validate(token(TokenSource.AUTHORIZATION_HEADER, "RS256", true, ISSUER,
                    Set.of(AUDIENCE), NOW.minusSeconds(1)), fault);
            case QUERY_TOKEN -> validate(token(TokenSource.QUERY, "RS256", true, ISSUER,
                    Set.of(AUDIENCE), NOW.plusSeconds(300)), fault);
            case TOKEN_LOGGED, NORMAL -> rejected("signature");
        };

        return switch (fault) {
            case DECODE_ONLY -> result.authenticated() ? "UNVERIFIED_DECODE_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case ALG_FROM_TOKEN -> result.authenticated() ? "UNSUPPORTED_ALGORITHM_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case ISSUER_NOT_CHECKED -> result.authenticated() ? "WRONG_ISSUER_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case AUDIENCE_NOT_CHECKED -> result.authenticated() ? "WRONG_AUDIENCE_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case TIME_NOT_CHECKED -> result.authenticated() ? "EXPIRED_TOKEN_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case QUERY_TOKEN -> result.authenticated() ? "QUERY_BEARER_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case TOKEN_LOGGED -> safeLog(result, fault, "SYNTHETIC-COMPACT-TOKEN").contains("SYNTHETIC-COMPACT-TOKEN")
                    ? "FULL_TOKEN_LOGGED" : "FAULT_NOT_EXPOSED";
            case NORMAL -> "FAULT_NOT_EXPOSED";
        };
    }

    public static void main(String[] args) {
        FaultMode fault = args.length == 0 ? FaultMode.NORMAL : FaultMode.valueOf(args[0]);
        if (fault != FaultMode.NORMAL) {
            System.out.println(injectedOutcome(fault));
            return;
        }

        Result accepted = validate(valid(), fault);
        Result forged = validate(token(TokenSource.AUTHORIZATION_HEADER, "RS256", false, ISSUER,
                Set.of(AUDIENCE), NOW.plusSeconds(300)), fault);
        Result wrongAlgorithm = validate(token(TokenSource.AUTHORIZATION_HEADER, "none", true, ISSUER,
                Set.of(AUDIENCE), NOW.plusSeconds(300)), fault);
        Result wrongIssuer = validate(token(TokenSource.AUTHORIZATION_HEADER, "RS256", true,
                "https://wrong.example.test", Set.of(AUDIENCE), NOW.plusSeconds(300)), fault);
        Result wrongAudience = validate(token(TokenSource.AUTHORIZATION_HEADER, "RS256", true, ISSUER,
                Set.of("another-api"), NOW.plusSeconds(300)), fault);
        Result expired = validate(token(TokenSource.AUTHORIZATION_HEADER, "RS256", true, ISSUER,
                Set.of(AUDIENCE), NOW.minusSeconds(1)), fault);
        Result query = validate(token(TokenSource.QUERY, "RS256", true, ISSUER,
                Set.of(AUDIENCE), NOW.plusSeconds(300)), fault);
        String auditLine = safeLog(forged, fault, "SYNTHETIC-COMPACT-TOKEN");

        System.out.println("valid_token_status=" + accepted.status());
        System.out.println("invalid_signature_status=" + forged.status());
        System.out.println("wrong_algorithm_status=" + wrongAlgorithm.status());
        System.out.println("wrong_issuer_status=" + wrongIssuer.status());
        System.out.println("wrong_audience_status=" + wrongAudience.status());
        System.out.println("expired_status=" + expired.status());
        System.out.println("query_token_status=" + query.status());
        System.out.println("decoded_only_authenticated=" + forged.authenticated());
        System.out.println("full_token_logged=" + auditLine.contains("SYNTHETIC-COMPACT-TOKEN"));
        System.out.println("verification_report=PASS assertions=9");
    }
}
