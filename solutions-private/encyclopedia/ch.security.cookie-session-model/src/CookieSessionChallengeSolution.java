/** Private oracle for Cookie scope and server-side Session lifecycle predicates. */
public final class CookieSessionChallengeSolution {
    enum SameSite { STRICT, LAX, NONE }
    enum RequestSite { SAME_SITE, CROSS_SITE_TOP_LEVEL_SAFE, CROSS_SITE_SUBRESOURCE }

    record CookieConfig(String originHost, String domain, String path,
                        boolean secure, boolean httpOnly, SameSite sameSite) { }

    record ServerSession(boolean revoked, boolean expired) { }

    private CookieSessionChallengeSolution() { }

    public static void main(String[] args) {
        CookieConfig safe = new CookieConfig(
                "api.factorycare.example.test", "", "/", true, true, SameSite.LAX);
        CookieConfig unsafe = new CookieConfig(
                "api.factorycare.example.test", "example.test", "/", true, true, SameSite.NONE);
        require(safeCookie(safe), "SAFE_COOKIE_REJECTED");
        require(!safeCookie(unsafe), "UNSAFE_COOKIE_ACCEPTED");

        require(shouldSend(safe, "https", "api.factorycare.example.test", "/api/v1/me",
                RequestSite.SAME_SITE), "SAME_SITE_HTTPS_REJECTED");
        require(!shouldSend(safe, "http", "api.factorycare.example.test", "/api/v1/me",
                RequestSite.SAME_SITE), "SECURE_COOKIE_SENT_OVER_HTTP");
        require(!shouldSend(safe, "https", "child.api.factorycare.example.test", "/api/v1/me",
                RequestSite.SAME_SITE), "HOST_ONLY_COOKIE_SENT_TO_SUBDOMAIN");
        require(!shouldSend(safe, "https", "api.factorycare.example.test", "/api/v1/me",
                RequestSite.CROSS_SITE_SUBRESOURCE), "LAX_COOKIE_SENT_CROSS_SITE_SUBRESOURCE");

        require(rotated("SYNTHETIC-PREAUTH-ID", "SYNTHETIC-AUTH-ID"), "ROTATION_REJECTED");
        require(!rotated("SYNTHETIC-SAME-ID", "SYNTHETIC-SAME-ID"), "FIXATION_REUSE_ACCEPTED");
        require(serverInvalidated(new ServerSession(true, false)), "REVOKED_SESSION_TREATED_ACTIVE");
        require(serverInvalidated(new ServerSession(false, true)), "EXPIRED_SESSION_TREATED_ACTIVE");
        require(!serverInvalidated(new ServerSession(false, false)), "ACTIVE_SESSION_TREATED_INVALID");

        require("SYNTHETIC-COOKIE-ID".equals(
                resolveSession("SYNTHETIC-COOKIE-ID", "SYNTHETIC-QUERY-ID")),
                "COOKIE_SESSION_SOURCE_IGNORED");
        require(resolveSession(null, "SYNTHETIC-QUERY-ID") == null, "QUERY_SESSION_ID_ACCEPTED");

        System.out.println("challenge_valid=true cookie=true rotation=true invalidation=true strict_source=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean safeCookie(CookieConfig cookie) {
        return cookie.domain().isBlank()
                && "/".equals(cookie.path())
                && cookie.secure()
                && cookie.httpOnly()
                && (cookie.sameSite() == SameSite.LAX || cookie.sameSite() == SameSite.STRICT);
    }

    static boolean shouldSend(CookieConfig cookie, String scheme, String host,
                              String requestPath, RequestSite requestSite) {
        if (cookie.secure() && !"https".equals(scheme)) {
            return false;
        }
        boolean hostMatches = cookie.domain().isBlank()
                ? cookie.originHost().equals(host)
                : host.equals(cookie.domain()) || host.endsWith("." + cookie.domain());
        if (!hostMatches || !pathMatches(cookie.path(), requestPath)) {
            return false;
        }
        return switch (cookie.sameSite()) {
            case STRICT -> requestSite == RequestSite.SAME_SITE;
            case LAX -> requestSite != RequestSite.CROSS_SITE_SUBRESOURCE;
            case NONE -> true;
        };
    }

    static boolean rotated(String preAuthId, String authenticatedId) {
        return preAuthId != null
                && authenticatedId != null
                && !preAuthId.isBlank()
                && !authenticatedId.isBlank()
                && !preAuthId.equals(authenticatedId);
    }

    static boolean serverInvalidated(ServerSession session) {
        return session.revoked() || session.expired();
    }

    static String resolveSession(String cookieValue, String queryValue) {
        return cookieValue;
    }

    private static boolean pathMatches(String cookiePath, String requestPath) {
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
