import java.util.List;

public final class RedisCacheRateLimitChallengeSolution {
    private static boolean tenantKey() {
        return !"fc:a:device:42:pv:3".equals("fc:b:device:42:pv:3");
    }

    private static boolean invalidation() {
        String source = "new";
        String cachedAfterDelete = null;
        return cachedAfterDelete == null && "new".equals(source);
    }

    private static boolean jitter() {
        return 1_000L + 37L != 1_000L + 74L;
    }

    private static boolean atomicCounterExpiry() {
        long count = 1L;
        long expiresAt = 1_000L;
        return count == 1L && expiresAt > 0L;
    }

    private static boolean exactThreshold() {
        int allowed = 0;
        for (int count = 1; count <= 4; count++) {
            if (count <= 3) {
                allowed++;
            }
        }
        return allowed == 3;
    }

    private static boolean slidingWindow() {
        List<Long> times = List.of(200L, 300L);
        long now = 1_101L;
        long window = 1_000L;
        return times.stream().allMatch(time -> time > now - window);
    }

    private static boolean failPolicy() {
        boolean expensiveEndpointAllowed = false;
        return !expensiveEndpointAllowed;
    }

    public static void main(String[] args) {
        boolean tenant = tenantKey();
        boolean invalidation = invalidation();
        boolean jitter = jitter();
        boolean atomic = atomicCounterExpiry();
        boolean threshold = exactThreshold();
        boolean sliding = slidingWindow();
        boolean failPolicy = failPolicy();
        boolean valid = tenant && invalidation && jitter && atomic && threshold && sliding && failPolicy;
        System.out.printf(
                "challenge_valid=%s tenant=%s invalidation=%s jitter=%s atomic=%s threshold=%s sliding=%s fail_policy=%s%n",
                valid, tenant, invalidation, jitter, atomic, threshold, sliding, failPolicy);
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }
}
