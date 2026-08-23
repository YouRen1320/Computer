import java.util.List;

public final class IndexBoundaryFailure {
    private IndexBoundaryFailure() {
    }

    public static void main(String[] args) {
        List<String> ids = List.of("WO-1", "WO-2");
        System.out.println(ids.get(ids.size()));
    }
}
