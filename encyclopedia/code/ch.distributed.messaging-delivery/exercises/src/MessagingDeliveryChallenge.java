public final class MessagingDeliveryChallenge {
    private static void require(boolean condition, String marker) {
        if (!condition) throw new IllegalStateException(marker);
    }

    public static void main(String[] args) {
        // TODO 1: commit business state and outbox together.
        require(false, "BUSINESS_OUTBOX_NOT_ATOMIC");
        // TODO 2: mark relay success only after publisher confirm.
        require(false, "MARKED_BEFORE_CONFIRM");
        // TODO 3: reuse the persisted eventId after an uncertain publish.
        require(false, "EVENT_ID_CHANGED_ON_RETRY");
        // TODO 4: acknowledge only after the consumer transaction commits.
        require(false, "ACK_BEFORE_COMMIT");
        // TODO 5: guard the side effect with consumer name plus eventId.
        require(false, "DUPLICATE_CONSUMER_EFFECT");
        // TODO 6: bound retries and add backoff instead of immediate requeue.
        require(false, "INFINITE_REQUEUE");
        // TODO 7: surface mandatory unroutable publications.
        require(false, "UNROUTABLE_IGNORED");
        // TODO 8: send permanent and unsupported failures to a governed DLQ.
        require(false, "PERMANENT_ERROR_RETRIED");
        System.out.println("challenge=PASS exactly_once_claim=false");
    }
}
