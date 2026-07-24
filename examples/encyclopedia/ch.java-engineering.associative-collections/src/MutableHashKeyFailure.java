import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

public final class MutableHashKeyFailure {
    private MutableHashKeyFailure() {
    }

    public static void main(String[] args) {
        Map<MutableKey, String> map = new HashMap<>();
        MutableKey key = new MutableKey("PUMP-01", 1);
        map.put(key, "ACTIVE");
        key.changeBucket(2);
        if (!map.containsKey(key)) {
            throw new IllegalStateException("LOST_HASH_KEY");
        }
    }

    private static final class MutableKey {
        private final String id;
        private int bucket;

        private MutableKey(String id, int bucket) {
            this.id = id;
            this.bucket = bucket;
        }

        private void changeBucket(int newBucket) {
            bucket = newBucket;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) {
                return true;
            }
            return other instanceof MutableKey that
                    && bucket == that.bucket
                    && Objects.equals(id, that.id);
        }

        @Override
        public int hashCode() {
            return bucket;
        }
    }
}
