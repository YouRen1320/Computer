/** Red starter for duplicate-delivery and stale-version boundaries. */
public final class IdempotencyConcurrencyChallenge {
    record Response(int status, String body, long version) { }

    private IdempotencyConcurrencyChallenge() { }

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
        // TODO replay only when the canonical request fingerprints match exactly.
        return true;
    }

    static boolean scopedKeyIncludesContext(
            String scopedKey, String tenant, String actor, String operation) {
        // TODO bind the key to trusted tenant, actor, and operation context.
        return true;
    }

    static boolean replayStoredResponse(Response stored, Response replay) {
        // TODO replay the saved status, body, and version instead of current resource state.
        return true;
    }

    static boolean claimBeforeSideEffect(boolean claimed, boolean sideEffectStarted) {
        // TODO permit a side effect only after this request owns the idempotency claim.
        return true;
    }

    static boolean versionMatches(long expected, long current) {
        // TODO require the command's expected version to equal the current version.
        return true;
    }

    static boolean updateCountHandled(int affectedRows) {
        // TODO treat exactly one affected row as success and zero as conflict.
        return true;
    }

    static boolean retrySafe(String originalState, String currentState) {
        // TODO reject an automatic retry after the state relevant to the intent changed.
        return true;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
