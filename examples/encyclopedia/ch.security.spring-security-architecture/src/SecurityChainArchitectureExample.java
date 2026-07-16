import java.util.List;
import java.util.Set;
import java.util.function.Predicate;

/** Offline model of first-match security chains, context lifetime, and 401/403 translation. */
public final class SecurityChainArchitectureExample {
    enum Policy { PUBLIC_ENTRY, APPLICATION }

    record Request(String method, String path, boolean credentialAccepted, Set<String> authorities) { }
    record Authentication(String principal, Set<String> authorities) { }
    record SecurityChain(String name, int order, Predicate<Request> matcher, Policy policy) { }
    record Decision(String chain, int status) { }

    static final class FilterChainProxyModel {
        private final List<SecurityChain> chains;
        private final ThreadLocal<Authentication> context = new ThreadLocal<>();

        FilterChainProxyModel(List<SecurityChain> chains) {
            this.chains = chains.stream().sorted((a, b) -> Integer.compare(a.order(), b.order())).toList();
        }

        Decision handle(Request request) {
            SecurityChain chain = chains.stream()
                    .filter(candidate -> candidate.matcher().test(request))
                    .findFirst()
                    .orElseThrow(() -> new IllegalStateException("NO_SECURITY_CHAIN"));
            try {
                if (request.credentialAccepted()) {
                    context.set(new Authentication("SYNTHETIC-ACTOR", request.authorities()));
                }
                return authorize(chain, request);
            } finally {
                context.remove();
            }
        }

        boolean contextCleared() {
            return context.get() == null;
        }

        private Decision authorize(SecurityChain chain, Request request) {
            if (chain.policy() == Policy.PUBLIC_ENTRY) {
                return new Decision(chain.name(), 204);
            }
            Authentication authentication = context.get();
            if (!request.path().startsWith("/api/v1/")) {
                return new Decision(chain.name(), 403);
            }
            if (authentication == null) {
                return new Decision(chain.name(), 401);
            }
            if (request.path().startsWith("/api/v1/audit/")
                    && !authentication.authorities().contains("AUDIT_EXPORT")) {
                return new Decision(chain.name(), 403);
            }
            return new Decision(chain.name(), 200);
        }
    }

    private SecurityChainArchitectureExample() { }

    public static void main(String[] args) {
        SecurityChain publicEntry = new SecurityChain(
                "PUBLIC_ENTRY", 1,
                request -> "POST".equals(request.method())
                        && "/api/v1/auth/login".equals(request.path()),
                Policy.PUBLIC_ENTRY);
        SecurityChain application = new SecurityChain(
                "APPLICATION", 2, request -> true, Policy.APPLICATION);
        FilterChainProxyModel proxy = new FilterChainProxyModel(List.of(publicEntry, application));

        Decision login = proxy.handle(request("POST", "/api/v1/auth/login", false));
        Decision unauthenticated = proxy.handle(request("GET", "/api/v1/auth/me", false));
        Decision forbidden = proxy.handle(request("POST", "/api/v1/audit/exports", true));
        Decision authorized = proxy.handle(request(
                "GET", "/api/v1/work-orders", true, "WORK_ORDER_READ"));
        Decision unknown = proxy.handle(request("GET", "/debug/config", true, "ADMIN"));

        require("PUBLIC_ENTRY".equals(login.chain()) && login.status() == 204,
                "PUBLIC_ENTRY_NOT_EXACT");
        require("APPLICATION".equals(unauthenticated.chain()) && unauthenticated.status() == 401,
                "UNAUTHENTICATED_NOT_401");
        require(forbidden.status() == 403, "AUTHENTICATED_DENIAL_NOT_403");
        require(authorized.status() == 200, "AUTHORIZED_REQUEST_REJECTED");
        require(unknown.status() == 403, "UNKNOWN_PATH_NOT_DENIED");
        require(proxy.contextCleared(), "SECURITY_CONTEXT_NOT_CLEARED");

        System.out.println("public_chain=" + login.chain());
        System.out.println("protected_chain=" + unauthenticated.chain());
        System.out.println("public_login_status=" + login.status());
        System.out.println("unauthenticated_status=" + unauthenticated.status());
        System.out.println("forbidden_status=" + forbidden.status());
        System.out.println("authorized_status=" + authorized.status());
        System.out.println("unknown_status=" + unknown.status());
        System.out.println("context_cleared=true");
        System.out.println("secret_material_printed=false");
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
