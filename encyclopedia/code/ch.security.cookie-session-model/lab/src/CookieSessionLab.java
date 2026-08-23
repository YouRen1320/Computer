import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/** Replays session fixation, logout, timeout, and cookie-scope faults without a network server. */
public final class CookieSessionLab {
    enum FaultMode { NONE, WIDE_COOKIE_SCOPE, FIXATION_REUSE, LOGOUT_CLIENT_ONLY, EXPIRED_ACCEPTED }
    enum State { ANONYMOUS, AUTHENTICATED, REVOKED, EXPIRED }

    record CookieConfig(String domain, String path, boolean secure, boolean httpOnly, String sameSite) { }
    record LogoutResult(boolean serverInvalidated, boolean clearCookie) { }

    static final class MutableClock {
        private Instant now = Instant.parse("2026-07-17T00:00:00Z");
        Instant now() { return now; }
        void advance(Duration duration) { now = now.plus(duration); }
    }

    static final class SessionRecord {
        final String id;
        final Instant createdAt;
        Instant lastSeenAt;
        State state;

        SessionRecord(String id, Instant now, State state) {
            this.id = id;
            this.createdAt = now;
            this.lastSeenAt = now;
            this.state = state;
        }
    }

    static final class SessionEngine {
        private final FaultMode faultMode;
        private final MutableClock clock;
        private final Map<String, SessionRecord> records = new LinkedHashMap<>();
        private int sequence;

        SessionEngine(FaultMode faultMode, MutableClock clock) {
            this.faultMode = faultMode;
            this.clock = clock;
        }

        String anonymous() {
            String id = next("PRE");
            records.put(id, new SessionRecord(id, clock.now(), State.ANONYMOUS));
            return id;
        }

        String login(String oldId) {
            SessionRecord old = records.get(oldId);
            if (old == null || old.state != State.ANONYMOUS) {
                throw new IllegalStateException("PREAUTH_INVALID");
            }
            if (faultMode == FaultMode.FIXATION_REUSE) {
                old.state = State.AUTHENTICATED;
                return oldId;
            }
            old.state = State.REVOKED;
            String newId = next("AUTH");
            records.put(newId, new SessionRecord(newId, clock.now(), State.AUTHENTICATED));
            return newId;
        }

        boolean access(String id) {
            SessionRecord session = records.get(id);
            if (session == null || session.state != State.AUTHENTICATED) {
                return false;
            }
            boolean expired = !clock.now().isBefore(session.lastSeenAt.plus(Duration.ofMinutes(10)))
                    || !clock.now().isBefore(session.createdAt.plus(Duration.ofHours(1)));
            if (expired && faultMode != FaultMode.EXPIRED_ACCEPTED) {
                session.state = State.EXPIRED;
                return false;
            }
            session.lastSeenAt = clock.now();
            return true;
        }

        LogoutResult logout(String id) {
            SessionRecord session = records.get(id);
            boolean serverInvalidated = false;
            if (session != null && faultMode != FaultMode.LOGOUT_CLIENT_ONLY) {
                session.state = State.REVOKED;
                serverInvalidated = true;
            }
            return new LogoutResult(serverInvalidated, true);
        }

        String resolveSessionId(String cookieValue, String queryValue) {
            return cookieValue;
        }

        private String next(String phase) {
            sequence++;
            return "SYNTHETIC-" + phase + "-ID-" + sequence;
        }
    }

    private CookieSessionLab() { }

    public static void main(String[] args) {
        FaultMode mode = args.length == 0 ? FaultMode.NONE : FaultMode.valueOf(args[0]);
        CookieConfig cookie = mode == FaultMode.WIDE_COOKIE_SCOPE
                ? new CookieConfig("example.test", "/", true, true, "Lax")
                : new CookieConfig("", "/", true, true, "Lax");
        require(safeCookieScope(cookie), "COOKIE_SCOPE_TOO_WIDE");

        MutableClock clock = new MutableClock();
        SessionEngine engine = new SessionEngine(mode, clock);
        String pre = engine.anonymous();
        String authenticated = engine.login(pre);
        require(!pre.equals(authenticated), "SESSION_ID_NOT_ROTATED");
        require(!engine.access(pre), "PREAUTH_ID_REUSABLE");
        require(engine.access(authenticated), "AUTHENTICATED_ID_REJECTED");
        require(engine.resolveSessionId(authenticated, "SYNTHETIC-QUERY-ID").equals(authenticated),
                "COOKIE_ID_NOT_PREFERRED");
        require(engine.resolveSessionId(null, "SYNTHETIC-QUERY-ID") == null, "URL_SESSION_ID_ACCEPTED");

        LogoutResult logout = engine.logout(authenticated);
        require(logout.serverInvalidated() && logout.clearCookie(), "LOGOUT_SERVER_STATE_NOT_INVALIDATED");
        require(!engine.access(authenticated), "LOGOUT_SESSION_REUSABLE");

        String expiring = engine.login(engine.anonymous());
        clock.advance(Duration.ofMinutes(10));
        require(!engine.access(expiring), "EXPIRED_SESSION_ACCEPTED");

        System.out.println("cookie_scope=HOST_ONLY");
        System.out.println("cookie_transport=SECURE_HTTPONLY_LAX");
        System.out.println("rotation=true");
        System.out.println("old_id_rejected=true");
        System.out.println("strict_id_source=true");
        System.out.println("logout_invalidation=true");
        System.out.println("idle_expiration=true");
        System.out.println("verification_report=PASS assertions=9");
    }

    static boolean safeCookieScope(CookieConfig cookie) {
        return cookie.domain().isBlank()
                && "/".equals(cookie.path())
                && cookie.secure()
                && cookie.httpOnly()
                && ("Lax".equals(cookie.sameSite()) || "Strict".equals(cookie.sameSite()));
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
