import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

public final class RedisCacheRateLimitExample {
    private record Device(String tenantId, String id, String name, long version) { }

    private static final class DeviceRepository {
        private final Map<String, Device> rows = new HashMap<>();
        private int loads;

        void save(Device device) {
            rows.put(device.tenantId() + "|" + device.id(), device);
        }

        Optional<Device> find(String tenantId, String id) {
            loads++;
            return Optional.ofNullable(rows.get(tenantId + "|" + id));
        }

        int loads() {
            return loads;
        }
    }

    private static final class SyntheticRedis {
        private final Map<String, Device> values = new HashMap<>();
        private final Map<String, Long> counters = new HashMap<>();
        private final Map<String, Long> expiresAt = new HashMap<>();
        private final Map<String, List<Long>> sliding = new HashMap<>();
        private boolean available = true;

        Device get(String key, long now) {
            requireAvailable();
            Long expiry = expiresAt.get(key);
            if (expiry != null && expiry <= now) {
                values.remove(key);
                expiresAt.remove(key);
            }
            return values.get(key);
        }

        void set(String key, Device value, long ttl, long now) {
            requireAvailable();
            values.put(key, value);
            expiresAt.put(key, now + ttl);
        }

        void delete(String key) {
            requireAvailable();
            values.remove(key);
            expiresAt.remove(key);
        }

        synchronized long incrementWithExpiry(String key, long ttl, long now) {
            requireAvailable();
            Long expiry = expiresAt.get(key);
            if (expiry != null && expiry <= now) {
                counters.remove(key);
                expiresAt.remove(key);
            }
            long next = counters.getOrDefault(key, 0L) + 1L;
            counters.put(key, next);
            expiresAt.putIfAbsent(key, now + ttl);
            return next;
        }

        synchronized boolean allowSliding(String key, int limit, long window, long now) {
            requireAvailable();
            List<Long> entries = sliding.computeIfAbsent(key, ignored -> new ArrayList<>());
            entries.removeIf(timestamp -> timestamp <= now - window);
            if (entries.size() >= limit) {
                return false;
            }
            entries.add(now);
            expiresAt.put(key, now + window);
            return true;
        }

        void available(boolean value) {
            available = value;
        }

        private void requireAvailable() {
            if (!available) {
                throw new IllegalStateException("REDIS_UNAVAILABLE");
            }
        }
    }

    private static final class DeviceCache {
        private final DeviceRepository repository;
        private final SyntheticRedis redis;

        DeviceCache(DeviceRepository repository, SyntheticRedis redis) {
            this.repository = repository;
            this.redis = redis;
        }

        Device get(String tenantId, String id, boolean authorized, long now) {
            if (!authorized) {
                throw new IllegalStateException("FORBIDDEN");
            }
            String key = key(tenantId, id);
            try {
                Device hit = redis.get(key, now);
                if (hit != null) {
                    return hit;
                }
            } catch (IllegalStateException unavailable) {
                return repository.find(tenantId, id).orElseThrow();
            }
            Device loaded = repository.find(tenantId, id).orElseThrow();
            redis.set(key, loaded, 1_000L, now);
            return loaded;
        }

        void update(Device updated) {
            repository.save(updated);
            redis.delete(key(updated.tenantId(), updated.id()));
        }

        private static String key(String tenantId, String id) {
            return "fc:" + tenantId + ":device:" + id + ":scope:reader:pv:3";
        }
    }

    private static final class RateLimiter {
        private final SyntheticRedis redis;

        RateLimiter(SyntheticRedis redis) {
            this.redis = redis;
        }

        boolean fixed(String tenant, String actor, int limit, long window, long now, boolean failOpen) {
            String key = "fc:rl:" + tenant + ":" + actor + ":read:" + (now / window);
            try {
                return redis.incrementWithExpiry(key, window + 1L, now) <= limit;
            } catch (IllegalStateException unavailable) {
                return failOpen;
            }
        }

        boolean sliding(String tenant, String actor, int limit, long window, long now) {
            return redis.allowSliding("fc:rl:sliding:" + tenant + ":" + actor, limit, window, now);
        }
    }

    public static void main(String[] args) {
        DeviceRepository repository = new DeviceRepository();
        repository.save(new Device("tenant-a", "42", "Pump-A", 1L));
        repository.save(new Device("tenant-b", "42", "Pump-B", 1L));
        SyntheticRedis redis = new SyntheticRedis();
        DeviceCache cache = new DeviceCache(repository, redis);

        Device miss = cache.get("tenant-a", "42", true, 0L);
        Device hit = cache.get("tenant-a", "42", true, 10L);
        System.out.println("miss_name=" + miss.name());
        System.out.println("hit_same=" + miss.equals(hit));
        System.out.println("source_loads_after_hit=" + repository.loads());
        Device otherTenant = cache.get("tenant-b", "42", true, 20L);
        System.out.println("tenant_isolated=" + !otherTenant.name().equals(hit.name()));

        cache.update(new Device("tenant-a", "42", "Pump-A2", 2L));
        System.out.println("updated_name=" + cache.get("tenant-a", "42", true, 30L).name());

        RateLimiter limiter = new RateLimiter(redis);
        StringBuilder fixed = new StringBuilder();
        for (int index = 0; index < 4; index++) {
            fixed.append(limiter.fixed("tenant-a", "alice", 3, 1_000L, index * 10L, false) ? 'A' : 'D');
        }
        System.out.println("fixed_sequence=" + fixed);

        StringBuilder sliding = new StringBuilder();
        for (long now : List.of(0L, 100L, 200L, 300L, 1_101L)) {
            sliding.append(limiter.sliding("tenant-a", "bob", 3, 1_000L, now) ? 'A' : 'D');
        }
        System.out.println("sliding_sequence=" + sliding);

        redis.available(false);
        System.out.println("redis_down_read=" + cache.get("tenant-a", "42", true, 40L).name());
        System.out.println("redis_down_ai=" + (limiter.fixed("tenant-a", "ai", 1, 1_000L, 40L, false) ? "ALLOW" : "DENY"));

        Set<String> completedCommands = new HashSet<>();
        int businessEffects = 0;
        if (completedCommands.add("tenant-a|close|cmd-1")) {
            businessEffects++;
        }
        if (completedCommands.add("tenant-a|close|cmd-1")) {
            businessEffects++;
        }
        System.out.println("business_effects=" + businessEffects);
        System.out.println("exactly_once_claim=false");
    }
}
