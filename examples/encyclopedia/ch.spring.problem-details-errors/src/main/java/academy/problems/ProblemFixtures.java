package academy.problems;

import java.net.URI;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RestControllerAdvice;

public final class ProblemFixtures {
    private static final String TYPE_ROOT = "https://factorycare.example/problems/";

    private ProblemFixtures() {
    }

    public record CreateWorkOrderRequest(
            @NotBlank String assetId,
            @NotBlank String description) {
    }

    public record WorkOrderResponse(long id, String status) {
    }

    public static final class WorkOrderNotFound extends RuntimeException {
        private final long workOrderId;

        public WorkOrderNotFound(long workOrderId) {
            super("Work order " + workOrderId + " was not found");
            this.workOrderId = workOrderId;
        }

        public long workOrderId() {
            return workOrderId;
        }
    }

    public static final class WorkOrderConflict extends RuntimeException {
        private final long workOrderId;
        private final String currentState;

        public WorkOrderConflict(long workOrderId, String currentState) {
            super("Cannot close work order " + workOrderId + " from " + currentState);
            this.workOrderId = workOrderId;
            this.currentState = currentState;
        }

        public long workOrderId() {
            return workOrderId;
        }

        public String currentState() {
            return currentState;
        }
    }

    public interface FailureReporter {
        void report(String traceId, Throwable failure);
    }

    public static final class RecordingFailureReporter implements FailureReporter {
        private String traceId;
        private Throwable failure;
        private int count;

        @Override
        public void report(String traceId, Throwable failure) {
            this.traceId = traceId;
            this.failure = failure;
            count++;
        }

        public String traceId() {
            return traceId;
        }

        public Throwable failure() {
            return failure;
        }

        public int count() {
            return count;
        }
    }

    @RestController
    @RequestMapping("/work-orders")
    public static final class WorkOrderController {
        @GetMapping(value = "/{id}", produces = MediaType.APPLICATION_JSON_VALUE)
        public WorkOrderResponse find(@PathVariable long id) {
            if (id == 404L) {
                throw new WorkOrderNotFound(id);
            }
            if (id == 500L) {
                throw new IllegalStateException("repository lookup failed",
                        new IllegalStateException(
                                "SQLException: select secret_token from work_order where id=500"));
            }
            return new WorkOrderResponse(id, "IN_PROGRESS");
        }

        @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE,
                produces = MediaType.APPLICATION_JSON_VALUE)
        public ResponseEntity<WorkOrderResponse> create(
                @Valid @RequestBody CreateWorkOrderRequest request) {
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new WorkOrderResponse(42L, "CREATED"));
        }

        @PostMapping(value = "/{id}/close", produces = MediaType.APPLICATION_JSON_VALUE)
        public WorkOrderResponse close(
                @PathVariable long id,
                @RequestHeader(name = "X-Current-State", defaultValue = "IN_PROGRESS")
                String currentState) {
            if (!"VERIFIED".equals(currentState)) {
                throw new WorkOrderConflict(id, currentState);
            }
            return new WorkOrderResponse(id, "CLOSED");
        }
    }

    @RestControllerAdvice
    public static final class ApiProblemAdvice {
        private final FailureReporter reporter;

        public ApiProblemAdvice(FailureReporter reporter) {
            this.reporter = reporter;
        }

        @ExceptionHandler(MethodArgumentNotValidException.class)
        public ProblemDetail validation(
                MethodArgumentNotValidException failure,
                HttpServletRequest request) {
            var problem = problem(
                    HttpStatus.BAD_REQUEST,
                    "validation",
                    "Request validation failed",
                    "One or more request fields are invalid",
                    "request.invalid",
                    request);
            List<Map<String, String>> errors = failure.getBindingResult().getFieldErrors().stream()
                    .map(ApiProblemAdvice::fieldProblem)
                    .sorted(Comparator
                            .comparing((Map<String, String> item) -> item.get("path"))
                            .thenComparing(item -> item.get("code")))
                    .toList();
            problem.setProperty("errors", errors);
            return problem;
        }

        @ExceptionHandler(WorkOrderNotFound.class)
        public ProblemDetail notFound(
                WorkOrderNotFound failure,
                HttpServletRequest request) {
            return problem(
                    HttpStatus.NOT_FOUND,
                    "work-order-not-found",
                    "Work order not found",
                    "No work order is available for id " + failure.workOrderId(),
                    "work-order.not-found",
                    request);
        }

        @ExceptionHandler(WorkOrderConflict.class)
        public ProblemDetail conflict(
                WorkOrderConflict failure,
                HttpServletRequest request) {
            return problem(
                    HttpStatus.CONFLICT,
                    "work-order-conflict",
                    "Work order state conflict",
                    "Refresh the work order and retry the command from a permitted state",
                    "work-order.state-conflict",
                    request);
        }

        @ExceptionHandler(Exception.class)
        public ProblemDetail unknown(Exception failure, HttpServletRequest request) {
            var traceId = traceId(request);
            reporter.report(traceId, failure);
            return problem(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "internal-error",
                    "Internal server error",
                    "The request could not be completed; contact support with the traceId",
                    "internal.error",
                    request);
        }

        private static ProblemDetail problem(
                HttpStatus status,
                String type,
                String title,
                String detail,
                String code,
                HttpServletRequest request) {
            var problem = ProblemDetail.forStatusAndDetail(status, detail);
            problem.setType(URI.create(TYPE_ROOT + type));
            problem.setTitle(title);
            problem.setInstance(URI.create(request.getRequestURI()));
            problem.setProperty("code", code);
            problem.setProperty("traceId", traceId(request));
            return problem;
        }

        private static Map<String, String> fieldProblem(FieldError error) {
            var code = "NotBlank".equals(error.getCode()) ? "required" : "invalid";
            var detail = "required".equals(code) ? "must not be blank" : "is invalid";
            return Map.of("path", error.getField(), "code", code, "detail", detail);
        }

        private static String traceId(HttpServletRequest request) {
            var candidate = request.getHeader("X-Trace-Id");
            return candidate != null && candidate.matches("[A-Za-z0-9._-]{1,64}")
                    ? candidate
                    : "generated-test-trace";
        }
    }
}
