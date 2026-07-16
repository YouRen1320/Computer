import java.util.List;
import java.util.Set;
import java.util.function.Predicate;

/** Starter for first-match chains, default denial, exception status, and context cleanup. */
public final class SecurityArchitectureChallenge {
    enum Requirement { PUBLIC, AUTHENTICATED, AUDIT_EXPORT, DENY }

    record Request(String method, String path) { }
    record Chain(String name, Predicate<Request> matcher) { }
    record Authentication(boolean authenticated, Set<String> authorities) { }

    private SecurityArchitectureChallenge() { }

    public static void main(String[] args) {
        Request loginPost = new Request("POST", "/api/v1/auth/login");
        Request loginGet = new Request("GET", "/api/v1/auth/login");
        require(exactPublicEntry(loginPost), "PUBLIC_POST_REJECTED");
        require(!exactPublicEntry(loginGet), "PUBLIC_MATCHER_TOO_WIDE");

        List<Chain> chains = List.of(
                new Chain("PUBLIC_ENTRY", SecurityArchitectureChallenge::exactPublicEntry),
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
        // TODO permit only POST on the exact controlled login path.
        return true;
    }

    static String selectFirst(Request request, List<Chain> chains) {
        // TODO return the name of the first matching chain, or NONE.
        return chains.getLast().name();
    }

    static boolean authorize(Requirement requirement, Authentication authentication) {
        // TODO implement public, authenticated, authority, and deny-by-default decisions.
        return true;
    }

    static int translateStatus(boolean authenticated, boolean authorized) {
        // TODO return 401 for missing authentication, 403 for denied identity, otherwise 200.
        return 200;
    }

    static boolean validFilterOrder(List<String> filters) {
        // TODO require context and authentication before authorization, with translation wrapping it.
        return true;
    }

    static void clearContext(ThreadLocal<Authentication> context) {
        // TODO remove the per-request authentication in every exit path.
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
