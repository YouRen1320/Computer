/** Green reference for duplicate-delivery and stale-version boundaries. */
public final class IdempotencyConcurrencyChallengeSolution {
    record Response(int status, String body, long version) { }

    private IdempotencyConcurrencyChallengeSolution() { }

    public static void main(String[] args) {
        require(sameFingerprint("FP-A", "FP-A"), "SAME_PAYLOAD_REJECTED");
        require(!sameFingerprint("FP-A", "FP-B"), "DIFFERENT_PAYLOAD_REPLAYED");
        require(scopedKeyIncludesContext(
                "tenant=TENANT-A|actor=ACTOR-7|operation=DISPATCH|key=KEY-1",
                "TENANT-A", "ACTOR-7", "DISPATCH"), "SCOPED_KEY_REJECTED");
        require(!scopedKeyIncludesContext("key=KEY-1", "TENANT-A", "ACTOR-7", "DISPATCH"),
                "UNSCOPED_KEY_ACCEPTED");

        Response saved = new Response(201, "ASSIGNED", 2);
        require(replayStoredResponse(saved, new Response(201, "ASSIGNED", 2)),
                "SAVED_RESPONSE_REJECTED");
        require(!replayStoredResponse(saved, new Response(200, "CURRENT", 3)),
                "CHANGED_RESPONSE_REPLAYED");
        require(claimBeforeSideEffect(true, true), "CLAIMED_EFFECT_REJECTED");
        require(!claimBeforeSideEffect(false, true), "SIDE_EFFECT_BEFORE_CLAIM");
        require(versionMatches(7, 7), "CURRENT_VERSION_REJECTED");
        require(!versionMatches(7, 8), "STALE_VERSION_ACCEPTED");
        require(updateCountHandled(1), "ONE_ROW_UPDATE_REJECTED");
        require(!updateCountHandled(0), "ZERO_ROW_UPDATE_REPORTED_SUCCESS");
        require(retrySafe("ASSIGNED", "ASSIGNED"), "UNCHANGED_RETRY_REJECTED");
        require(!retrySafe("ASSIGNED", "CANCELLED"), "STALE_COMMAND_REAPPLIED");

        System.out.println("challenge_valid=true fingerprint=true scope=true replay=true claim=true version=true update_count=true retry=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean sameFingerprint(String stored, String incoming) {
        return stored != null && stored.equals(incoming);
    }

    static boolean scopedKeyIncludesContext(
            String scopedKey, String tenant, String actor, String operation) {
        String prefix = "tenant=" + tenant + "|actor=" + actor + "|operation=" + operation + "|key=";
        return scopedKey != null && scopedKey.startsWith(prefix) && scopedKey.length() > prefix.length();
    }

    static boolean replayStoredResponse(Response stored, Response replay) {
        return stored != null && stored.equals(replay);
    }

    static boolean claimBeforeSideEffect(boolean claimed, boolean sideEffectStarted) {
        return claimed || !sideEffectStarted;
    }

    static boolean versionMatches(long expected, long current) {
        return expected == current;
    }

    static boolean updateCountHandled(int affectedRows) {
        return affectedRows == 1;
    }

    static boolean retrySafe(String originalState, String currentState) {
        return originalState != null && originalState.equals(currentState);
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
