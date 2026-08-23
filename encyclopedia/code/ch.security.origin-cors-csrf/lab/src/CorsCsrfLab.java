import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/** Offline fault-injection lab for exact CORS responses and CSRF write protection. */
public final class CorsCsrfLab {
    enum FaultMode { NONE, WILDCARD_CREDENTIALS, CSRF_DISABLED, REFERER_ONLY, GET_MUTATES }

    record Origin(String scheme, String host, int port) {
        String serialized() {
            boolean defaultPort = ("https".equals(scheme) && port == 443)
                    || ("http".equals(scheme) && port == 80);
            return scheme + "://" + host + (defaultPort ? "" : ":" + port);
        }
    }

    record CorsPolicy(Set<String> origins, boolean credentials,
                      Set<String> methods, Set<String> headers) { }

    record Request(String method, Origin source, Origin target, String sessionCookie,
                   String csrfToken, String referer, String requestedMethod,
                   Set<String> requestedHeaders) { }

    record Response(int status, Map<String, String> headers, boolean wrote) { }

    static final class BrowserBoundary {
        private static final String SESSION = "SYNTHETIC-SESSION";
        private static final String TOKEN = "SYNTHETIC-CSRF";
        private final FaultMode mode;
        private final CorsPolicy policy;
        private int writes;

        BrowserBoundary(FaultMode mode, CorsPolicy policy) {
            this.mode = mode;
            this.policy = policy;
        }

        Response handle(Request request) {
            // Preflight is intentionally handled before Session authentication.
            if ("OPTIONS".equals(request.method())) {
                return preflight(request);
            }
            Map<String, String> headers = actualCorsHeaders(request);
            if (!SESSION.equals(request.sessionCookie())) {
                return new Response(401, headers, false);
            }
            if (safeMethod(request.method())) {
                boolean wrote = mode == FaultMode.GET_MUTATES;
                if (wrote) {
                    writes++;
                }
                return new Response(200, headers, wrote);
            }
            if (!csrfAccepted(request)) {
                return new Response(403, headers, false);
            }
            writes++;
            return new Response(204, headers, true);
        }

        int writes() {
            return writes;
        }

        private Response preflight(Request request) {
            boolean allowed = originAllowed(request.source())
                    && policy.methods().contains(request.requestedMethod())
                    && policy.headers().containsAll(request.requestedHeaders());
            if (!allowed) {
                return new Response(403, Map.of(), false);
            }
            Map<String, String> headers = actualCorsHeaders(request);
            headers.put("Access-Control-Allow-Methods", String.join(", ", policy.methods()));
            headers.put("Access-Control-Allow-Headers", String.join(", ", policy.headers()));
            return new Response(204, Map.copyOf(headers), false);
        }

        private Map<String, String> actualCorsHeaders(Request request) {
            if (sameOrigin(request.source(), request.target()) || !originAllowed(request.source())) {
                return new LinkedHashMap<>();
            }
            Map<String, String> headers = new LinkedHashMap<>();
            headers.put("Access-Control-Allow-Origin",
                    policy.origins().contains("*") ? "*" : request.source().serialized());
            if (policy.credentials()) {
                headers.put("Access-Control-Allow-Credentials", "true");
            }
            headers.put("Vary", "Origin");
            return headers;
        }

        private boolean originAllowed(Origin source) {
            return policy.origins().contains("*") || policy.origins().contains(source.serialized());
        }

        private boolean csrfAccepted(Request request) {
            if (mode == FaultMode.CSRF_DISABLED) {
                return true;
            }
            if (mode == FaultMode.REFERER_ONLY) {
                return request.referer() != null
                        && request.referer().startsWith("https://app.factorycare.example.test");
            }
            boolean trustedOrigin = sameOrigin(request.source(), request.target())
                    || policy.origins().contains(request.source().serialized());
            return trustedOrigin && TOKEN.equals(request.csrfToken());
        }
    }

    private static final Origin API = new Origin("https", "api.factorycare.example.test", 443);
    private static final Origin APP = new Origin("https", "app.factorycare.example.test", 443);
    private static final Origin EVIL = new Origin("https", "evil.example.test", 443);

    private CorsCsrfLab() { }

    public static void main(String[] args) {
        FaultMode mode = args.length == 0 ? FaultMode.NONE : FaultMode.valueOf(args[0]);
        CorsPolicy policy = new CorsPolicy(
                mode == FaultMode.WILDCARD_CREDENTIALS ? Set.of("*") : Set.of(APP.serialized()),
                true, Set.of("GET", "POST"), Set.of("content-type", "x-csrf-token"));
        require(validCredentialedPolicy(policy), "WILDCARD_WITH_CREDENTIALS");
        BrowserBoundary boundary = new BrowserBoundary(mode, policy);

        Response preflight = boundary.handle(new Request(
                "OPTIONS", APP, API, null, null, null, "POST", Set.of("x-csrf-token")));
        require(preflight.status() == 204, "PREFLIGHT_WITHOUT_SESSION_REJECTED");
        require(APP.serialized().equals(preflight.headers().get("Access-Control-Allow-Origin")),
                "ALLOWED_ORIGIN_HEADER_NOT_EXACT");
        require("true".equals(preflight.headers().get("Access-Control-Allow-Credentials")),
                "CREDENTIAL_RESPONSE_FLAG_MISSING");
        require("Origin".equals(preflight.headers().get("Vary")), "VARY_ORIGIN_MISSING");

        Response unknown = boundary.handle(new Request(
                "OPTIONS", EVIL, API, null, null, null, "POST", Set.of("x-csrf-token")));
        require(unknown.status() == 403
                && !unknown.headers().containsKey("Access-Control-Allow-Origin"),
                "UNKNOWN_ORIGIN_AUTHORIZED");

        Response allowedWrite = boundary.handle(request(
                "POST", APP, "SYNTHETIC-SESSION", "SYNTHETIC-CSRF",
                "https://app.factorycare.example.test/tickets"));
        require(allowedWrite.status() == 204 && allowedWrite.wrote(), "TOKEN_WRITE_REJECTED");

        Response missingToken = boundary.handle(request(
                "POST", APP, "SYNTHETIC-SESSION", null, null));
        require(missingToken.status() == 403 && !missingToken.wrote(), "MISSING_CSRF_TOKEN_ACCEPTED");

        Response crossSiteForm = boundary.handle(request(
                "POST", EVIL, "SYNTHETIC-SESSION", null,
                "https://app.factorycare.example.test.attacker.example.test/form"));
        require(crossSiteForm.status() == 403 && !crossSiteForm.wrote(), "ORIGIN_MISMATCH_ACCEPTED");

        Response safeGet = boundary.handle(request(
                "GET", API, "SYNTHETIC-SESSION", null, null));
        require(safeGet.status() == 200 && !safeGet.wrote(), "GET_PRODUCED_SIDE_EFFECT");
        require(boundary.writes() == 1, "UNEXPECTED_WRITE_COUNT");

        System.out.println("allowed_origin_header=EXACT");
        System.out.println("preflight_without_session=true");
        System.out.println("unknown_origin_authorized_header=false");
        System.out.println("credentialed_post_with_token=true");
        System.out.println("missing_token_rejected=true");
        System.out.println("cross_site_form_rejected=true");
        System.out.println("get_side_effects=0");
        System.out.println("verification_report=PASS assertions=8");
    }

    static boolean validCredentialedPolicy(CorsPolicy policy) {
        return !(policy.credentials() && policy.origins().contains("*"));
    }

    static boolean sameOrigin(Origin left, Origin right) {
        return left.scheme().equals(right.scheme())
                && left.host().equals(right.host())
                && left.port() == right.port();
    }

    static boolean safeMethod(String method) {
        return "GET".equals(method) || "HEAD".equals(method) || "OPTIONS".equals(method);
    }

    static Request request(String method, Origin source, String sessionCookie,
                           String csrfToken, String referer) {
        return new Request(method, source, API, sessionCookie, csrfToken, referer, null, Set.of());
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
