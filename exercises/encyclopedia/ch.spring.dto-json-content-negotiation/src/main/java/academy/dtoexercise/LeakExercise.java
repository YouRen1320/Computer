package academy.dtoexercise;

import java.math.BigDecimal;

public final class LeakExercise {
    private LeakExercise() {}

    public record WorkOrder(
            long id,
            String assetId,
            String description,
            String priority,
            String status,
            BigDecimal internalCost,
            String assigneeToken) {}

    public static Object response() {
        return new WorkOrder(42, "ASSET-7", "pump vibration", "HIGH", "OPEN",
                new BigDecimal("999.99"), "never-publish-this-token");
    }
}
