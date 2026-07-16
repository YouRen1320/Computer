import java.util.List;
import java.util.Set;
import java.util.function.Predicate;

/** Private oracle for first-match chains, default denial, exception status, and cleanup. */
public final class SecurityArchitectureChallengeSolution {
    enum Requirement { PUBLIC, AUTHENTICATED, AUDIT_EXPORT, DENY }

    record Request(String method, String path) { }
    record Chain(String name, Predicate<Request> matcher) { }
    record Authentication(boolean authenticated, Set<String> authorities) { }

    private SecurityArchitectureChallengeSolution() { }

    public static void main(String[] args) {
        Request loginPost = new Request("POST", "/api/v1/auth/login");
        Request loginGet = new Request("GET", "/api/v1/auth/login");
        require(exactPublicEntry(loginPost), "PUBLIC_POST_REJECTED");
        require(!exactPublicEntry(loginGet), "PUBLIC_MATCHER_TOO_WIDE");

        List<Chain> chains = List.of(
                new Chain("PUBLIC_ENTRY", SecurityArchitectureChallengeSolution::exactPublicEntry),
                new Chain("APPLICATION", request -> true));
        require("PUBLIC_ENTRY".equals(selectFirst(loginPost, chains)), "FIRST_CHAIN_NOT_SELECTED");
        require("APPLICATION".equals(selectFirst(
                new Request("GET", "/api/v1/auth/me"), chains)), "APPLICATION_CHAIN_NOT_SELECTED");

        Authentication anonymous = new Authentication(false, Set.of());
        Authentication reader = new Authentication(true, Set.of("WORK_ORDER_READ"));
        Authentication auditor = new Authentication(true, Set.of("AUDIT_EXPORT"));
        require(authorize(Requirement.PUBLIC, anonymous), "PUBLIC_REQUEST_REJECTED");
        require(!authorize(Requirement.AUTHENTICATED, anonymous), "ANONYMOUS_DEFAULT_ALLOWED");
        require(authorize(Requirement.AUTHENTICATED, reader), "AUTHENTICATED_REQUEST_REJECTED");
        require(!authorize(Requirement.AUDIT_EXPORT, reader), "MISSING_AUTHORITY_ACCEPTED");
        require(authorize(Requirement.AUDIT_EXPORT, auditor), "AUDIT_AUTHORITY_REJECTED");
        require(!authorize(Requirement.DENY, auditor), "DEFAULT_DENY_BROKEN");

        require(translateStatus(false, false) == 401, "UNAUTHENTICATED_NOT_401");
        require(translateStatus(true, false) == 403, "FORBIDDEN_NOT_403");
        require(translateStatus(true, true) == 200, "AUTHORIZED_NOT_200");

        List<String> filters = List.of(
                "SecurityContextHolderFilter", "SyntheticAuthenticationFilter",
                "ExceptionTranslationFilter", "AuthorizationFilter");
        require(validFilterOrder(filters), "FILTER_DEPENDENCY_ORDER_BROKEN");

        ThreadLocal<Authentication> context = new ThreadLocal<>();
        context.set(reader);
        clearContext(context);
        require(context.get() == null, "SECURITY_CONTEXT_NOT_CLEARED");

        System.out.println("challenge_valid=true first_match=true default_deny=true exceptions=true order=true cleanup=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean exactPublicEntry(Request request) {
        return "POST".equals(request.method()) && "/api/v1/auth/login".equals(request.path());
    }

    static String selectFirst(Request request, List<Chain> chains) {
        return chains.stream()
                .filter(chain -> chain.matcher().test(request))
                .map(Chain::name)
                .findFirst()
                .orElse("NONE");
    }

    static boolean authorize(Requirement requirement, Authentication authentication) {
        return switch (requirement) {
            case PUBLIC -> true;
            case AUTHENTICATED -> authentication.authenticated();
            case AUDIT_EXPORT -> authentication.authenticated()
                    && authentication.authorities().contains("AUDIT_EXPORT");
            case DENY -> false;
        };
    }

    static int translateStatus(boolean authenticated, boolean authorized) {
        if (!authenticated) {
            return 401;
        }
        return authorized ? 200 : 403;
    }

    static boolean validFilterOrder(List<String> filters) {
        int context = filters.indexOf("SecurityContextHolderFilter");
        int authentication = filters.indexOf("SyntheticAuthenticationFilter");
        int translation = filters.indexOf("ExceptionTranslationFilter");
        int authorization = filters.indexOf("AuthorizationFilter");
        return context >= 0
                && context < authentication
                && authentication < authorization
                && translation >= 0
                && translation < authorization;
    }

    static void clearContext(ThreadLocal<Authentication> context) {
        context.remove();
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
