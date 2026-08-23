package academy.problemexercise;

import java.net.URI;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RestControllerAdvice;

public final class ConflictBoundary {
    private ConflictBoundary() {
    }

    public static final class WorkOrderConflict extends RuntimeException {
        public WorkOrderConflict() {
            super("internal state=IN_PROGRESS cannot close");
        }
    }

    @RestController
    public static final class ConflictController {
        @PostMapping("/work-orders/42/close")
        public void close() {
            throw new WorkOrderConflict();
        }
    }

    @RestControllerAdvice
    public static final class ConflictAdvice {
        @ExceptionHandler(WorkOrderConflict.class)
        public ResponseEntity<ProblemDetail> conflict(
                WorkOrderConflict failure,
                HttpServletRequest request) {
            var problem = ProblemDetail.forStatusAndDetail(
                    HttpStatus.CONFLICT,
                    "Refresh the work order before retrying the command");
            problem.setType(URI.create(
                    "https://factorycare.example/problems/work-order-conflict"));
            problem.setTitle("Work order state conflict");
            problem.setInstance(URI.create(request.getRequestURI()));
            problem.setProperty("code", "work-order.state-conflict");
            return ResponseEntity.ok(problem);
        }
    }
}
