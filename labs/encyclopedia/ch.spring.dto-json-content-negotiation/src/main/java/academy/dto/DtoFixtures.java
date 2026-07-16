package academy.dto;

import java.math.BigDecimal;
import java.util.concurrent.atomic.AtomicInteger;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

public final class DtoFixtures {
    private DtoFixtures() {}

    public enum Priority { LOW, HIGH }

    public record CreateWorkOrderRequest(
            String assetId,
            String description,
            Priority priority) {}

    public record WorkOrderResponse(
            long id,
            String assetId,
            String description,
            Priority priority,
            String status) {}

    public record WorkOrder(
            long id,
            String assetId,
            String description,
            Priority priority,
            String status,
            BigDecimal internalCost,
            String assigneeToken) {}

    public interface CreateWorkOrderUseCase {
        WorkOrder create(CreateWorkOrderRequest request);
    }

    public static final class RecordingUseCase implements CreateWorkOrderUseCase {
        private final AtomicInteger calls = new AtomicInteger();

        @Override
        public WorkOrder create(CreateWorkOrderRequest request) {
            calls.incrementAndGet();
            return new WorkOrder(
                    42,
                    request.assetId(),
                    request.description(),
                    request.priority(),
                    "OPEN",
                    new BigDecimal("999.99"),
                    "never-publish-this-token");
        }

        public int callCount() {
            return calls.get();
        }
    }

    public static WorkOrderResponse toResponse(WorkOrder workOrder) {
        return new WorkOrderResponse(
                workOrder.id(),
                workOrder.assetId(),
                workOrder.description(),
                workOrder.priority(),
                workOrder.status());
    }

    @RestController
    @RequestMapping("/work-orders")
    public static final class WorkOrderJsonController {
        private final CreateWorkOrderUseCase useCase;

        public WorkOrderJsonController(CreateWorkOrderUseCase useCase) {
            this.useCase = useCase;
        }

        @PostMapping(
                consumes = MediaType.APPLICATION_JSON_VALUE,
                produces = MediaType.APPLICATION_JSON_VALUE)
        public ResponseEntity<WorkOrderResponse> create(
                @RequestBody CreateWorkOrderRequest request) {
            return ResponseEntity.status(201).body(toResponse(useCase.create(request)));
        }
    }
}
