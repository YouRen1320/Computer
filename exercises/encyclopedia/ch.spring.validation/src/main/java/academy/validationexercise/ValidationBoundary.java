package academy.validationexercise;

import java.util.concurrent.atomic.AtomicInteger;

import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

public final class ValidationBoundary {
    private ValidationBoundary() {
    }

    public record CreateRequest(@NotBlank String description) {
    }

    public static final class RecordingUseCase {
        private final AtomicInteger calls = new AtomicInteger();

        public long create(CreateRequest request) {
            calls.incrementAndGet();
            return 42L;
        }

        public int callCount() {
            return calls.get();
        }
    }

    @RestController
    @RequestMapping("/work-orders")
    public static final class WorkOrderController {
        private final RecordingUseCase useCase;

        public WorkOrderController(RecordingUseCase useCase) {
            this.useCase = useCase;
        }

        @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE,
                produces = MediaType.TEXT_PLAIN_VALUE)
        public ResponseEntity<String> create(@RequestBody CreateRequest request) {
            var id = useCase.create(request);
            return ResponseEntity.status(HttpStatus.CREATED).body("created=" + id);
        }
    }
}
