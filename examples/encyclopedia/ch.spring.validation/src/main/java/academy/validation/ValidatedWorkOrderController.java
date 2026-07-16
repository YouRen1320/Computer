package academy.validation;

import jakarta.validation.Valid;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/work-orders")
public final class ValidatedWorkOrderController {
    private final RecordingCreateUseCase useCase;

    public ValidatedWorkOrderController(RecordingCreateUseCase useCase) {
        this.useCase = useCase;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> create(@Valid @RequestBody CreateWorkOrderRequest request) {
        return ResponseEntity.status(201).body("created=" + useCase.create(request));
    }
}
