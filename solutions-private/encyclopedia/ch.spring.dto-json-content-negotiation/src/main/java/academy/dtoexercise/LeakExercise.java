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

    public record WorkOrderResponse(
            long id,
            String assetId,
            String description,
            String priority,
            String status) {}

    public static Object response() {
        WorkOrder workOrder = new WorkOrder(42, "ASSET-7", "pump vibration", "HIGH", "OPEN",
                new BigDecimal("999.99"), "never-publish-this-token");
        return new WorkOrderResponse(
                workOrder.id(),
                workOrder.assetId(),
                workOrder.description(),
                workOrder.priority(),
                workOrder.status());
    }
}
