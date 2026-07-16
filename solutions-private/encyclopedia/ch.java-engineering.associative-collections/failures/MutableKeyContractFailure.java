import java.util.HashMap;
import java.util.Map;

public final class MutableKeyContractFailure {
    private MutableKeyContractFailure() {
    }

    public static void main(String[] args) {
        Map<MutableKey, String> map = new HashMap<>();
        MutableKey key = new MutableKey(1);
        map.put(key, "OPEN");
        key.bucket = 2;
        if (!map.containsKey(key)) {
            throw new IllegalStateException("LOST_HASH_KEY");
        }
    }

    private static final class MutableKey {
        private int bucket;

        private MutableKey(int bucket) {
            this.bucket = bucket;
        }

        @Override
        public int hashCode() {
            return bucket;
        }
    }
}
