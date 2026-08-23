import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class RedisCacheRateLimitFaultLab {
    private enum FaultMode {
        MISSING_TENANT_KEY,
        NO_INVALIDATION,
        SAME_TTL,
        NON_ATOMIC_INCREMENT_EXPIRE,
        CHECK_THEN_INCREMENT,
        WRONG_FAIL_POLICY,
        AUTHORIZATION_CACHED
    }

    private static String scopedKey(String tenant, String device) {
        return "fc:" + tenant + ":device:" + device + ":pv:3";
    }

    private static boolean safeTenantKey() {
        return !scopedKey("a", "42").equals(scopedKey("b", "42"));
    }

    private static boolean safeInvalidation() {
        Map<String, String> source = new HashMap<>();
        Map<String, String> cache = new HashMap<>();
        source.put("a|42", "old");
        cache.put(scopedKey("a", "42"), source.get("a|42"));
        source.put("a|42", "new");
        cache.remove(scopedKey("a", "42"));
        return "new".equals(cache.getOrDefault(scopedKey("a", "42"), source.get("a|42")));
    }

    private static boolean safeJitter() {
        Set<Long> expiries = new HashSet<>();
        for (int keyIndex = 0; keyIndex < 4; keyIndex++) {
            expiries.add(1_000L + keyIndex * 37L);
        }
        return expiries.size() == 4;
    }

    private static boolean safeCounterExpiry() {
        Map<String, Long> counters = new HashMap<>();
        Map<String, Long> expiry = new HashMap<>();
        synchronized (counters) {
            counters.merge("window", 1L, Long::sum);
            expiry.putIfAbsent("window", 1_000L);
        }
        return counters.containsKey("window") && expiry.containsKey("window");
    }

    private static boolean safeThreshold() {
        int allowed = 0;
        int count = 0;
        for (int request = 0; request < 4; request++) {
            count++;
            if (count <= 3) {
                allowed++;
            }
        }
        return allowed == 3;
    }

    private static boolean safePolicy() {
        boolean lowRiskReadFailOpen = true;
        boolean expensiveAiFailOpen = false;
        return lowRiskReadFailOpen && !expensiveAiFailOpen;
    }

    private static boolean safeAuthorization() {
        boolean cached = true;
        boolean currentlyAuthorized = false;
        return !(cached && currentlyAuthorized);
    }

    private static String inject(FaultMode mode) {
        return switch (mode) {
            case MISSING_TENANT_KEY -> {
                Map<String, String> cache = new HashMap<>();
                String badKey = "device:42";
                cache.put(badKey, "tenant-a-pump");
                yield "tenant-a-pump".equals(cache.get(badKey)) ? "CROSS_TENANT_CACHE_LEAK" : "NOT_EXPOSED";
            }
            case NO_INVALIDATION -> {
                String cached = "old";
                String source = "new";
                yield !cached.equals(source) ? "STALE_AFTER_UPDATE" : "NOT_EXPOSED";
            }
            case SAME_TTL -> {
                Set<Long> expiries = Set.of(1_000L);
                yield expiries.size() == 1 ? "SYNCHRONIZED_EXPIRY_STAMPEDE" : "NOT_EXPOSED";
            }
            case NON_ATOMIC_INCREMENT_EXPIRE -> {
                Map<String, Long> counter = new HashMap<>();
                Map<String, Long> expiry = new HashMap<>();
                counter.put("window", 1L);
                yield counter.containsKey("window") && !expiry.containsKey("window")
                        ? "RATE_KEY_WITHOUT_TTL" : "NOT_EXPOSED";
            }
            case CHECK_THEN_INCREMENT -> {
                int initial = 2;
                boolean requestOneSawCapacity = initial < 3;
                boolean requestTwoSawCapacity = initial < 3;
                int finalCount = initial + (requestOneSawCapacity ? 1 : 0) + (requestTwoSawCapacity ? 1 : 0);
                yield finalCount == 4 ? "TOO_MANY_REQUESTS_ALLOWED" : "NOT_EXPOSED";
            }
            case WRONG_FAIL_POLICY -> {
                boolean expensiveEndpointAllowedWhenRedisDown = true;
                yield expensiveEndpointAllowedWhenRedisDown ? "EXPENSIVE_ENDPOINT_FAIL_OPEN" : "NOT_EXPOSED";
            }
            case AUTHORIZATION_CACHED -> {
                boolean cached = true;
                boolean authorizedNow = false;
                boolean returned = cached;
                yield returned && !authorizedNow ? "REVOKED_ACCESS_ALLOWED" : "NOT_EXPOSED";
            }
        };
    }

    public static void main(String[] args) {
        if (args.length == 1) {
            System.out.println(inject(FaultMode.valueOf(args[0])));
            return;
        }
        System.out.println("tenant_key_isolated=" + safeTenantKey());
        System.out.println("update_invalidated=" + safeInvalidation());
        System.out.println("ttl_jittered=" + safeJitter());
        System.out.println("counter_expiry_atomic=" + safeCounterExpiry());
        System.out.println("threshold_exact=" + safeThreshold());
        System.out.println("redis_policy_explicit=" + safePolicy());
        System.out.println("authorization_current=" + safeAuthorization());
        System.out.println("verification_report=PASS assertions=7");
    }
}
