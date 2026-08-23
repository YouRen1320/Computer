import java.util.List;
import java.util.Set;
import java.util.function.Predicate;

/** Offline fault injection for first-match chains, filter order, context cleanup, and exceptions. */
public final class SecurityChainLab {
    enum FaultMode {
        NONE, WIDE_MATCHER_FIRST, ANONYMOUS_DEFAULT_ALLOW,
        FILTER_ORDER, NO_CATCH_ALL, CONTEXT_NOT_CLEARED, WRONG_EXCEPTION_MAPPING
    }

    enum Policy { PUBLIC_ENTRY, APPLICATION }

    record Request(String method, String path, boolean credentialAccepted, Set<String> authorities) { }
    record Authentication(Set<String> authorities) { }
    record Chain(String name, int order, Predicate<Request> matcher, Policy policy) { }
    record Decision(String chain, int status) { }

    static final class Engine {
        private final FaultMode mode;
        private final List<Chain> chains;
        private final ThreadLocal<Authentication> context = new ThreadLocal<>();

        Engine(FaultMode mode) {
            this.mode = mode;
            Predicate<Request> publicMatcher = mode == FaultMode.WIDE_MATCHER_FIRST
                    ? request -> request.path().startsWith("/api/v1/")
                    : request -> "POST".equals(request.method())
                            && "/api/v1/auth/login".equals(request.path());
            Predicate<Request> applicationMatcher = mode == FaultMode.NO_CATCH_ALL
                    ? request -> request.path().startsWith("/api/v1/")
                    : request -> true;
            this.chains = List.of(
                    new Chain("PUBLIC_ENTRY", 1, publicMatcher, Policy.PUBLIC_ENTRY),
                    new Chain("APPLICATION", 2, applicationMatcher, Policy.APPLICATION));
        }

        Decision handle(Request request) {
            Chain selected = chains.stream()
                    .sorted((a, b) -> Integer.compare(a.order(), b.order()))
                    .filter(chain -> chain.matcher().test(request))
                    .findFirst()
                    .orElse(null);
            if (selected == null) {
                return new Decision("NONE", 200);
            }
            try {
                if (mode == FaultMode.FILTER_ORDER) {
                    Decision decision = authorize(selected, request);
                    loadContext(request);
                    return decision;
                }
                loadContext(request);
                return authorize(selected, request);
            } finally {
                if (mode != FaultMode.CONTEXT_NOT_CLEARED) {
                    context.remove();
                }
            }
        }

        boolean contextCleared() {
            return context.get() == null;
        }

        private void loadContext(Request request) {
            if (request.credentialAccepted()) {
                context.set(new Authentication(request.authorities()));
            }
        }

        private Decision authorize(Chain selected, Request request) {
            if (selected.policy() == Policy.PUBLIC_ENTRY) {
                return new Decision(selected.name(), 204);
            }
            Authentication authentication = context.get();
            if (!request.path().startsWith("/api/v1/")) {
                return new Decision(selected.name(), 403);
            }
            if (authentication == null) {
                if (mode == FaultMode.ANONYMOUS_DEFAULT_ALLOW) {
                    return new Decision(selected.name(), 200);
                }
                return new Decision(selected.name(), mode == FaultMode.WRONG_EXCEPTION_MAPPING ? 403 : 401);
            }
            if (request.path().startsWith("/api/v1/audit/")
                    && !authentication.authorities().contains("AUDIT_EXPORT")) {
                return new Decision(selected.name(), 403);
            }
            return new Decision(selected.name(), 200);
        }
    }

    private SecurityChainLab() { }

    public static void main(String[] args) {
        FaultMode mode = args.length == 0 ? FaultMode.NONE : FaultMode.valueOf(args[0]);
        Engine engine = new Engine(mode);

        Decision unauthenticated = engine.handle(request("GET", "/api/v1/auth/me", false));
        require(!"PUBLIC_ENTRY".equals(unauthenticated.chain()), "PROTECTED_ENDPOINT_BYPASSED");
        require(unauthenticated.status() == 401, mode == FaultMode.WRONG_EXCEPTION_MAPPING
                ? "UNAUTHENTICATED_NOT_401" : "ANONYMOUS_DEFAULT_ALLOWED");

        Decision authorized = engine.handle(request(
                "GET", "/api/v1/work-orders", true, "WORK_ORDER_READ"));
        require(authorized.status() == 200, "AUTHENTICATION_NOT_VISIBLE_AT_AUTHORIZATION");
        require(engine.contextCleared(), "SECURITY_CONTEXT_NOT_CLEARED");

        Decision forbidden = engine.handle(request("POST", "/api/v1/audit/exports", true));
        require(forbidden.status() == 403, "AUTHENTICATED_DENIAL_NOT_403");
        Decision unknown = engine.handle(request("GET", "/debug/config", true, "ADMIN"));
        require(!"NONE".equals(unknown.chain()) && unknown.status() == 403,
                "UNMATCHED_REQUEST_UNPROTECTED");

        Decision login = engine.handle(request("POST", "/api/v1/auth/login", false));
        require("PUBLIC_ENTRY".equals(login.chain()) && login.status() == 204,
                "PUBLIC_ENDPOINT_NOT_EXACT");
        Decision loginGet = engine.handle(request("GET", "/api/v1/auth/login", false));
        require("APPLICATION".equals(loginGet.chain()) && loginGet.status() == 401,
                "PUBLIC_METHOD_TOO_WIDE");

        System.out.println("public_endpoint_exact=true");
        System.out.println("protected_default_authenticated=true");
        System.out.println("unknown_default_denied=true");
        System.out.println("unauthenticated_status=401");
        System.out.println("forbidden_status=403");
        System.out.println("filter_order=context_before_authorization");
        System.out.println("context_cleared=true");
        System.out.println("verification_report=PASS assertions=9");
    }

    static Request request(String method, String path, boolean accepted, String... authorities) {
        return new Request(method, path, accepted, Set.of(authorities));
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
