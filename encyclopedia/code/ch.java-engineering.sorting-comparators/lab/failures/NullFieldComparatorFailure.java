import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public final class NullFieldComparatorFailure {
    private NullFieldComparatorFailure() {
    }

    public static void main(String[] args) {
        List<Item> items = new ArrayList<>(List.of(
                new Item("A", null),
                new Item("B", LocalDateTime.parse("2026-07-16T09:00"))));
        items.sort(Comparator.comparing(Item::dueAt));
    }

    private record Item(String id, LocalDateTime dueAt) {
    }
}
