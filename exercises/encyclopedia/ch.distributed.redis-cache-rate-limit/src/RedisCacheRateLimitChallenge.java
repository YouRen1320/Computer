public final class RedisCacheRateLimitChallenge {
    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }

    public static void main(String[] args) {
        // TODO 1: bind the cache key to the trusted tenant and projection version.
        boolean tenantInKey = false;
        require(tenantInKey, "MISSING_TENANT_IN_KEY");

        // TODO 2: invalidate only after the database update commits.
        boolean invalidatesAfterCommit = false;
        require(invalidatesAfterCommit, "STALE_AFTER_UPDATE");

        // TODO 3: apply deterministic TTL jitter to avoid synchronized expiry.
        boolean ttlJittered = false;
        require(ttlJittered, "SYNCHRONIZED_EXPIRY");

        // TODO 4: combine increment and first expiry in one atomic decision.
        boolean counterExpiryAtomic = false;
        require(counterExpiryAtomic, "COUNTER_WITHOUT_EXPIRY");

        // TODO 5: allow exactly limit requests and reject limit + 1.
        boolean thresholdExact = false;
        require(thresholdExact, "THRESHOLD_OVERRUN");

        // TODO 6: remove timestamps outside the sliding window before deciding.
        boolean slidingPruned = false;
        require(slidingPruned, "OLD_REQUESTS_NOT_PRUNED");

        // TODO 7: fail closed for the expensive AI endpoint when Redis is unavailable.
        boolean expensiveEndpointFailClosed = false;
        require(expensiveEndpointFailClosed, "EXPENSIVE_ENDPOINT_FAIL_OPEN");
        System.out.println("challenge=PASS");
    }
}
