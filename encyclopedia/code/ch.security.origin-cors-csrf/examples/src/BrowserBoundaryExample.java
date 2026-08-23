import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/** Offline browser-boundary example; every host and credential marker is synthetic. */
public final class BrowserBoundaryExample {
    record Origin(String scheme, String host, int port) {
        String serialized() {
            boolean defaultPort = ("https".equals(scheme) && port == 443)
                    || ("http".equals(scheme) && port == 80);
            return scheme + "://" + host + (defaultPort ? "" : ":" + port);
        }
    }

    record Request(String method, Origin source, Origin target, String sessionCookie,
                   String csrfToken, String preflightMethod, Set<String> preflightHeaders) { }

    record Response(int status, Map<String, String> headers, boolean wrote) { }

    record CorsPolicy(Set<String> allowedOrigins, boolean allowCredentials,
                      Set<String> allowedMethods, Set<String> allowedHeaders) { }

    static final class BoundaryEngine {
        private static final String SYNTHETIC_SESSION = "SYNTHETIC-BROWSER-SESSION";
        private static final String SYNTHETIC_CSRF = "SYNTHETIC-CSRF-TOKEN";
        private final CorsPolicy cors;

        BoundaryEngine(CorsPolicy cors) {
            this.cors = cors;
        }

        Response handle(Request request) {
            // CORS preflight is evaluated before authentication because it carries no Session Cookie.
            if ("OPTIONS".equals(request.method())) {
                return preflight(request);
            }

            Map<String, String> headers = corsHeaders(request);
            if (!SYNTHETIC_SESSION.equals(request.sessionCookie())) {
                return new Response(401, headers, false);
            }
            if (isSafe(request.method())) {
                return new Response(200, headers, false);
            }

            boolean trustedSource = sameOrigin(request.source(), request.target())
                    || cors.allowedOrigins().contains(request.source().serialized());
            boolean csrfValid = trustedSource && SYNTHETIC_CSRF.equals(request.csrfToken());
            return csrfValid
                    ? new Response(204, headers, true)
                    : new Response(403, headers, false);
        }

        private Response preflight(Request request) {
            boolean allowed = cors.allowedOrigins().contains(request.source().serialized())
                    && cors.allowedMethods().contains(request.preflightMethod())
                    && cors.allowedHeaders().containsAll(request.preflightHeaders());
            if (!allowed) {
                return new Response(403, Map.of(), false);
            }
            Map<String, String> headers = corsHeaders(request);
            headers.put("Access-Control-Allow-Methods", String.join(", ", cors.allowedMethods()));
            headers.put("Access-Control-Allow-Headers", String.join(", ", cors.allowedHeaders()));
            return new Response(204, Map.copyOf(headers), false);
        }

        private Map<String, String> corsHeaders(Request request) {
            if (sameOrigin(request.source(), request.target())
                    || !cors.allowedOrigins().contains(request.source().serialized())) {
                return new LinkedHashMap<>();
            }
            Map<String, String> headers = new LinkedHashMap<>();
            headers.put("Access-Control-Allow-Origin", request.source().serialized());
            if (cors.allowCredentials()) {
                headers.put("Access-Control-Allow-Credentials", "true");
            }
            headers.put("Vary", "Origin");
            return headers;
        }
    }

    private static final Origin API = new Origin("https", "api.factorycare.example.test", 443);
    private static final Origin APP = new Origin("https", "app.factorycare.example.test", 443);
    private static final Origin EVIL = new Origin("https", "evil.example.test", 443);

    private BrowserBoundaryExample() { }

    public static void main(String[] args) {
        CorsPolicy policy = new CorsPolicy(
                Set.of(APP.serialized()), true,
                Set.of("GET", "POST"), Set.of("content-type", "x-csrf-token"));
        BoundaryEngine engine = new BoundaryEngine(policy);

        Response sameOriginGet = engine.handle(request("GET", API, API,
                "SYNTHETIC-BROWSER-SESSION", null));
        require(sameOriginGet.status() == 200 && !sameOriginGet.wrote(), "SAFE_GET_BOUNDARY_BROKEN");

        Response allowedPreflight = engine.handle(new Request(
                "OPTIONS", APP, API, null, null, "POST", Set.of("x-csrf-token")));
        require(allowedPreflight.status() == 204, "ALLOWED_PREFLIGHT_REJECTED");
        require(APP.serialized().equals(allowedPreflight.headers().get("Access-Control-Allow-Origin")),
                "PREFLIGHT_ORIGIN_NOT_EXACT");
        require("true".equals(allowedPreflight.headers().get("Access-Control-Allow-Credentials")),
                "PREFLIGHT_CREDENTIALS_MISSING");
        require("Origin".equals(allowedPreflight.headers().get("Vary")), "VARY_ORIGIN_MISSING");

        Response allowedPost = engine.handle(request("POST", APP, API,
                "SYNTHETIC-BROWSER-SESSION", "SYNTHETIC-CSRF-TOKEN"));
        require(allowedPost.status() == 204 && allowedPost.wrote(), "ALLOWED_CREDENTIAL_POST_REJECTED");
        require(APP.serialized().equals(allowedPost.headers().get("Access-Control-Allow-Origin")),
                "ACTUAL_RESPONSE_ORIGIN_NOT_EXACT");

        Response unknownPreflight = engine.handle(new Request(
                "OPTIONS", EVIL, API, null, null, "POST", Set.of("x-csrf-token")));
        require(unknownPreflight.status() == 403
                && !unknownPreflight.headers().containsKey("Access-Control-Allow-Origin"),
                "UNKNOWN_ORIGIN_AUTHORIZED");

        Response crossSiteForm = engine.handle(request("POST", EVIL, API,
                "SYNTHETIC-BROWSER-SESSION", null));
        require(crossSiteForm.status() == 403 && !crossSiteForm.wrote(), "CROSS_SITE_FORM_ACCEPTED");

        Response missingToken = engine.handle(request("POST", APP, API,
                "SYNTHETIC-BROWSER-SESSION", null));
        require(missingToken.status() == 403 && !missingToken.wrote(), "MISSING_CSRF_ACCEPTED");

        CorsPolicy invalid = new CorsPolicy(
                Set.of("*"), true, Set.of("GET", "POST"), Set.of("x-csrf-token"));
        require(!validCredentialedPolicy(invalid), "WILDCARD_CREDENTIALS_ACCEPTED");

        System.out.println("same_origin_get_status=" + sameOriginGet.status());
        System.out.println("same_origin_get_writes=0");
        System.out.println("allowed_preflight_status=" + allowedPreflight.status());
        System.out.println("preflight_requires_session=false");
        System.out.println("allowed_credentialed_post_status=" + allowedPost.status());
        System.out.println("unknown_origin_authorized_header=false");
        System.out.println("cross_site_form_status=" + crossSiteForm.status());
        System.out.println("missing_csrf_status=" + missingToken.status());
        System.out.println("wildcard_with_credentials_valid=false");
        System.out.println("secret_material_printed=false");
    }

    static boolean sameOrigin(Origin left, Origin right) {
        return left.scheme().equals(right.scheme())
                && left.host().equals(right.host())
                && left.port() == right.port();
    }

    static boolean validCredentialedPolicy(CorsPolicy policy) {
        return !(policy.allowCredentials() && policy.allowedOrigins().contains("*"));
    }

    static boolean isSafe(String method) {
        return "GET".equals(method) || "HEAD".equals(method) || "OPTIONS".equals(method);
    }

    static Request request(String method, Origin source, Origin target,
                           String sessionCookie, String csrfToken) {
        return new Request(method, source, target, sessionCookie, csrfToken, null, Set.of());
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
