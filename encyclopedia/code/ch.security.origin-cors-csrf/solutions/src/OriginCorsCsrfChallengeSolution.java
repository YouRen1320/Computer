import java.util.Set;

/** Private oracle for exact origin/CORS matching and browser-session CSRF predicates. */
public final class OriginCorsCsrfChallengeSolution {
    record Origin(String scheme, String host, int port) {
        String serialized() {
            boolean defaultPort = ("https".equals(scheme) && port == 443)
                    || ("http".equals(scheme) && port == 80);
            return scheme + "://" + host + (defaultPort ? "" : ":" + port);
        }
    }

    private static final Origin API = new Origin("https", "api.factorycare.example.test", 443);
    private static final Origin APP = new Origin("https", "app.factorycare.example.test", 443);
    private static final Origin EVIL_SUFFIX =
            new Origin("https", "app.factorycare.example.test.attacker.example.test", 443);
    private static final Set<String> ALLOWED = Set.of(APP.serialized());

    private OriginCorsCsrfChallengeSolution() { }

    public static void main(String[] args) {
        require(exactAllowedOrigin(APP, ALLOWED), "ALLOWED_ORIGIN_REJECTED");
        require(!exactAllowedOrigin(EVIL_SUFFIX, ALLOWED), "ORIGIN_SUFFIX_BYPASS");

        require(sameOrigin(API, new Origin("https", "api.factorycare.example.test", 443)),
                "IDENTICAL_ORIGIN_REJECTED");
        require(!sameOrigin(API, new Origin("http", "api.factorycare.example.test", 443)),
                "SCHEME_CHANGE_TREATED_SAME_ORIGIN");
        require(!sameOrigin(API, new Origin("https", "api.factorycare.example.test", 8443)),
                "PORT_CHANGE_TREATED_SAME_ORIGIN");

        require(validCredentialedCors(APP.serialized(), true, APP.serialized()),
                "EXACT_CREDENTIAL_CORS_REJECTED");
        require(!validCredentialedCors("*", true, APP.serialized()),
                "WILDCARD_CREDENTIALS_ACCEPTED");
        require(!preflightNeedsSession(), "PREFLIGHT_REQUIRES_SESSION");

        require(csrfAllowed("POST", true, APP, API, ALLOWED,
                "SYNTHETIC-CSRF", "SYNTHETIC-CSRF"), "VALID_CSRF_REJECTED");
        require(!csrfAllowed("POST", true, APP, API, ALLOWED,
                null, "SYNTHETIC-CSRF"), "MISSING_CSRF_ACCEPTED");
        require(!csrfAllowed("POST", true, EVIL_SUFFIX, API, ALLOWED,
                "SYNTHETIC-CSRF", "SYNTHETIC-CSRF"), "EVIL_ORIGIN_ACCEPTED");

        require(signedDoubleSubmit("SYNTHETIC-CSRF", "SYNTHETIC-CSRF", true, true),
                "SIGNED_DOUBLE_SUBMIT_REJECTED");
        require(!signedDoubleSubmit("SYNTHETIC-CSRF", "SYNTHETIC-CSRF", false, true),
                "NAIVE_DOUBLE_SUBMIT_ACCEPTED");
        require(!signedDoubleSubmit("SYNTHETIC-CSRF", "SYNTHETIC-CSRF", true, false),
                "UNBOUND_DOUBLE_SUBMIT_ACCEPTED");

        require(mayMutate("POST"), "POST_MUTATION_REJECTED");
        require(!mayMutate("GET"), "GET_MUTATION_ACCEPTED");

        System.out.println("challenge_valid=true origin=true cors=true csrf=true double_submit=true safe_method=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean exactAllowedOrigin(Origin source, Set<String> allowedOrigins) {
        return allowedOrigins.contains(source.serialized());
    }

    static boolean sameOrigin(Origin left, Origin right) {
        return left.scheme().equals(right.scheme())
                && left.host().equals(right.host())
                && left.port() == right.port();
    }

    static boolean validCredentialedCors(String allowOrigin, boolean allowCredentials,
                                         String requestOrigin) {
        return !allowCredentials || (!"*".equals(allowOrigin) && requestOrigin.equals(allowOrigin));
    }

    static boolean preflightNeedsSession() {
        return false;
    }

    static boolean csrfAllowed(String method, boolean browserSession, Origin requestOrigin,
                               Origin targetOrigin, Set<String> allowedOrigins,
                               String token, String expectedToken) {
        if (safeMethod(method) || !browserSession) {
            return true;
        }
        boolean trustedOrigin = sameOrigin(requestOrigin, targetOrigin)
                || exactAllowedOrigin(requestOrigin, allowedOrigins);
        return trustedOrigin && token != null && token.equals(expectedToken);
    }

    static boolean signedDoubleSubmit(String cookieToken, String headerToken,
                                      boolean signatureValid, boolean sessionBound) {
        return cookieToken != null
                && !cookieToken.isBlank()
                && cookieToken.equals(headerToken)
                && signatureValid
                && sessionBound;
    }

    static boolean mayMutate(String method) {
        return "POST".equals(method) || "PUT".equals(method)
                || "PATCH".equals(method) || "DELETE".equals(method);
    }

    private static boolean safeMethod(String method) {
        return "GET".equals(method) || "HEAD".equals(method) || "OPTIONS".equals(method);
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
