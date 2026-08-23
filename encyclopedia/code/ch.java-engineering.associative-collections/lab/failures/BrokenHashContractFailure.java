import java.util.HashSet;
import java.util.Objects;
import java.util.Set;

public final class BrokenHashContractFailure {
    private BrokenHashContractFailure() {
    }

    public static void main(String[] args) {
        Set<BrokenKey> keys = new HashSet<>();
        keys.add(new BrokenKey("PUMP-01", 1));
        keys.add(new BrokenKey("PUMP-01", 2));
        if (keys.size() == 2) {
            throw new IllegalStateException("BROKEN_EQUAL_HASH");
        }
    }

    private record BrokenKey(String id, int wrongHash) {
        @Override
        public boolean equals(Object other) {
            return this == other || other instanceof BrokenKey that
                    && Objects.equals(id, that.id);
        }

        @Override
        public int hashCode() {
            return wrongHash;
        }
    }
}
