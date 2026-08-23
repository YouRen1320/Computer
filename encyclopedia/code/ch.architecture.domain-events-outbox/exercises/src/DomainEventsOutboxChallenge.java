public final class DomainEventsOutboxChallenge {
    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }

    public static void main(String[] args) {
        // TODO 1: write aggregate state and outbox through one database transaction.
        boolean atomicStateAndEvent = false;
        require(atomicStateAndEvent, "STATE_AND_EVENT_NOT_ATOMIC");

        // TODO 2: create the fact only after the domain state transition succeeds.
        boolean eventAfterStateChange = false;
        require(eventAfterStateChange, "EVENT_BEFORE_STATE_CHANGE");

        // TODO 3: persist one stable eventId and reuse it for every relay attempt.
        boolean stableEventId = false;
        require(stableEventId, "EVENT_ID_CHANGED_ON_RETRY");

        // TODO 4: include eventType and an explicit supported payload version.
        boolean payloadVersioned = false;
        require(payloadVersioned, "PAYLOAD_VERSION_MISSING");

        // TODO 5: protect each consumer side effect by consumer name plus eventId.
        boolean consumerIdempotent = false;
        require(consumerIdempotent, "DUPLICATE_CONSUMER_EFFECT");

        // TODO 6: mark PUBLISHED only after transport accepts the event.
        boolean markAfterSend = false;
        require(markAfterSend, "MARKED_BEFORE_SEND");

        // TODO 7: give every in-flight claim an expiry and owner guard.
        boolean claimRecoverable = false;
        require(claimRecoverable, "CLAIM_NEVER_RECOVERS");

        // TODO 8: quarantine unsupported versions without guessing fields.
        boolean unsupportedQuarantined = false;
        require(unsupportedQuarantined, "UNSUPPORTED_VERSION_GUESSED");
        System.out.println("challenge=PASS exactly_once_claim=false");
    }
}
