import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/** Offline cookie-scope and server-session lifecycle example using synthetic identifiers only. */
public final class CookieSessionExample {
    enum SameSite { STRICT, LAX, NONE }
    enum RequestSite { SAME_SITE, CROSS_SITE_TOP_LEVEL_SAFE, CROSS_SITE_SUBRESOURCE }
    enum SessionState { ANONYMOUS, AUTHENTICATED, REVOKED, EXPIRED }

    record CookiePolicy(String name, String originHost, String domain, String path,
                        boolean secure, boolean httpOnly, SameSite sameSite,
                        Long maxAgeSeconds) { }

    static final class MutableClock {
        private Instant now = Instant.parse("2026-07-17T00:00:00Z");
        Instant now() { return now; }
        void advance(Duration duration) { now = now.plus(duration); }
    }

    static final class Session {
        final String id;
        final Instant createdAt;
        Instant lastSeenAt;
        SessionState state;
        String accountId;

        Session(String id, Instant now) {
            this.id = id;
            this.createdAt = now;
            this.lastSeenAt = now;
            this.state = SessionState.ANONYMOUS;
        }
    }

    static final class TestOnlyIdSource {
        private int sequence;
        String next(String phase) { return "SYNTHETIC-" + phase + "-SESSION-" + ++sequence; }
    }

    static final class SessionStore {
        private final MutableClock clock;
        private final TestOnlyIdSource ids;
        private final Map<String, Session> sessions = new LinkedHashMap<>();
        private final Duration idleTimeout = Duration.ofMinutes(5);
        private final Duration absoluteTimeout = Duration.ofMinutes(30);

        SessionStore(MutableClock clock, TestOnlyIdSource ids) {
            this.clock = clock;
            this.ids = ids;
        }

        String startAnonymous() {
            String id = ids.next("PREAUTH");
            sessions.put(id, new Session(id, clock.now()));
            return id;
        }

        String login(String anonymousId, String syntheticAccountId) {
            Session old = sessions.get(anonymousId);
            if (old == null || old.state != SessionState.ANONYMOUS) {
                throw new IllegalStateException("PREAUTH_SESSION_INVALID");
            }
            old.state = SessionState.REVOKED;
            String newId = ids.next("AUTHENTICATED");
            Session authenticated = new Session(newId, clock.now());
            authenticated.state = SessionState.AUTHENTICATED;
            authenticated.accountId = syntheticAccountId;
            sessions.put(newId, authenticated);
            return newId;
        }

        boolean access(String id) {
            Session session = sessions.get(id);
            if (session == null || session.state != SessionState.AUTHENTICATED) {
                return false;
            }
            boolean idleExpired = !clock.now().isBefore(session.lastSeenAt.plus(idleTimeout));
            boolean absoluteExpired = !clock.now().isBefore(session.createdAt.plus(absoluteTimeout));
            if (idleExpired || absoluteExpired) {
                session.state = SessionState.EXPIRED;
                return false;
            }
            session.lastSeenAt = clock.now();
            return true;
        }

        void logout(String id) {
            Session session = sessions.get(id);
            if (session != null) {
                session.state = SessionState.REVOKED;
            }
        }
    }

    private CookieSessionExample() { }

    public static void main(String[] args) {
        CookiePolicy policy = new CookiePolicy(
                "FACTORYCARE_SESSION", "api.factorycare.example.test", "", "/",
                true, true, SameSite.LAX, null);
        require(validPolicy(policy), "COOKIE_POLICY_INVALID");
        require(sentTo(policy, "https", "api.factorycare.example.test", "/api/v1/me", RequestSite.SAME_SITE),
                "EXPECTED_COOKIE_NOT_SENT");
        require(!sentTo(policy, "http", "api.factorycare.example.test", "/api/v1/me", RequestSite.SAME_SITE),
                "SECURE_COOKIE_SENT_OVER_HTTP");
        require(!sentTo(policy, "https", "evil.api.factorycare.example.test", "/api/v1/me", RequestSite.SAME_SITE),
                "HOST_ONLY_COOKIE_SENT_TO_SUBDOMAIN");
        require(!sentTo(policy, "https", "api.factorycare.example.test", "/api/v1/me", RequestSite.CROSS_SITE_SUBRESOURCE),
                "LAX_COOKIE_SENT_CROSS_SITE_SUBRESOURCE");

        MutableClock clock = new MutableClock();
        SessionStore store = new SessionStore(clock, new TestOnlyIdSource());
        String preAuth = store.startAnonymous();
        String authenticated = store.login(preAuth, "SYNTHETIC-ACCOUNT-1");
        require(!preAuth.equals(authenticated), "SESSION_ID_NOT_ROTATED");
        require(!store.access(preAuth), "PREAUTH_SESSION_REUSED");
        require(store.access(authenticated), "AUTHENTICATED_SESSION_REJECTED");
        store.logout(authenticated);
        require(!store.access(authenticated), "LOGOUT_SESSION_REUSED");

        String secondPreAuth = store.startAnonymous();
        String expiring = store.login(secondPreAuth, "SYNTHETIC-ACCOUNT-1");
        clock.advance(Duration.ofMinutes(5));
        require(!store.access(expiring), "EXPIRED_SESSION_ACCEPTED");

        System.out.println("cookie_policy_valid=true");
        System.out.println("https_host_path_match=true");
        System.out.println("http_rejected=true");
        System.out.println("subdomain_rejected=true");
        System.out.println("cross_site_subresource_rejected=true");
        System.out.println("login_rotated_id=true");
        System.out.println("preauth_id_rejected=true");
        System.out.println("authenticated_session_accepted=true");
        System.out.println("logout_server_invalidated=true");
        System.out.println("expired_session_rejected=true");
        System.out.println("secret_material_printed=false");
    }

    static boolean validPolicy(CookiePolicy policy) {
        if (!policy.secure() || !policy.httpOnly() || policy.path().isBlank()) {
            return false;
        }
        if (policy.sameSite() == SameSite.NONE && !policy.secure()) {
            return false;
        }
        if (policy.name().startsWith("__Host-")) {
            return policy.domain().isBlank() && "/".equals(policy.path());
        }
        return policy.domain().isBlank() && policy.maxAgeSeconds() == null;
    }

    static boolean sentTo(CookiePolicy policy, String scheme, String host,
                          String requestPath, RequestSite requestSite) {
        if (policy.secure() && !"https".equals(scheme)) {
            return false;
        }
        boolean hostMatches = policy.domain().isBlank()
                ? policy.originHost().equals(host)
                : host.equals(policy.domain()) || host.endsWith("." + policy.domain());
        if (!hostMatches || !pathMatches(policy.path(), requestPath)) {
            return false;
        }
        return switch (policy.sameSite()) {
            case STRICT -> requestSite == RequestSite.SAME_SITE;
            case LAX -> requestSite != RequestSite.CROSS_SITE_SUBRESOURCE;
            case NONE -> true;
        };
    }

    static boolean pathMatches(String cookiePath, String requestPath) {
        if (requestPath.equals(cookiePath)) {
            return true;
        }
        if (!requestPath.startsWith(cookiePath)) {
            return false;
        }
        return cookiePath.endsWith("/") || requestPath.charAt(cookiePath.length()) == '/';
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
