package factorycare.testing;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.MethodOrderer.OrderAnnotation;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;

@TestMethodOrder(OrderAnnotation.class)
final class SharedFixturePollutionFault {
    private static final StaticRepository REPOSITORY = new StaticRepository();
    private static final DispatchService SERVICE = new DispatchService(
            REPOSITORY,
            (recipient, message) -> { },
            Clock.fixed(Instant.parse("2026-07-17T04:00:00Z"), ZoneOffset.UTC),
            () -> "D-SHARED");

    @Test
    @Order(1)
    void firstTestMutatesStaticFixture() {
        SERVICE.create(new DispatchService.Command("shared-source", "tech-1", 2));
        assertEquals(1, REPOSITORY.size());
    }

    @Test
    @Order(2)
    void secondTestIncorrectlyAssumesAnEmptyWorld() {
        assertEquals(0, REPOSITORY.size(), "static fixture leaked from the previous test");
    }

    private static final class StaticRepository implements DispatchService.Repository {
        private final List<DispatchService.Dispatch> saved = new ArrayList<>();

        @Override
        public boolean existsBySourceKey(String sourceKey) {
            return saved.stream().anyMatch(value -> value.sourceKey().equals(sourceKey));
        }

        @Override
        public void save(DispatchService.Dispatch dispatch) {
            saved.add(dispatch);
        }

        int size() {
            return saved.size();
        }
    }
}
