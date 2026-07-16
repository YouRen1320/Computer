import java.util.List;

public final class UnmodifiableMutationFailure {
    private UnmodifiableMutationFailure() {
    }

    public static void main(String[] args) {
        List<String> snapshot = List.copyOf(List.of("RECEIVED"));
        snapshot.add("ASSIGNED");
    }
}
