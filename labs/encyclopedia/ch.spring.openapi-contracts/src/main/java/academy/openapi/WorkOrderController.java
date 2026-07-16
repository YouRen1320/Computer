package academy.openapi;

import io.swagger.v3.oas.annotations.*;
import io.swagger.v3.oas.annotations.media.*;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

/** One FactoryCare-shaped operation whose generated description is checked against runtime HTTP. */
@RestController
@RequestMapping("/api/v1/work-orders")
public final class WorkOrderController {
    public record WorkOrderResponse(
            @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "wo-7") String id,
            @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "IN_PROGRESS") String status,
            @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "3") long version,
            @Schema(example = "2026-07-18T08:00:00Z") String slaDueAt) {}
    public record ApiProblem(
            @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "work-order.not-found") String code,
            @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "Work order not found") String message,
            @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "trace-contract-lab") String traceId) {}

    @Operation(operationId = "getWorkOrder", summary = "Read one authorized work order", responses = {
            @ApiResponse(responseCode = "200", description = "Work order found", content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = WorkOrderResponse.class), examples = @ExampleObject(name = "success", value = "{\"id\":\"wo-7\",\"status\":\"IN_PROGRESS\",\"version\":3}"))),
            @ApiResponse(responseCode = "404", description = "No visible work order", content = @Content(mediaType = MediaType.APPLICATION_PROBLEM_JSON_VALUE, schema = @Schema(implementation = ApiProblem.class), examples = @ExampleObject(name = "missing", value = "{\"code\":\"work-order.not-found\",\"message\":\"Work order not found\",\"traceId\":\"trace-contract-lab\"}")))
    })
    @GetMapping(value = "/{id}", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> get(@Parameter(example = "wo-7") @PathVariable String id) {
        if ("missing".equals(id)) return ResponseEntity.status(HttpStatus.NOT_FOUND).contentType(MediaType.APPLICATION_PROBLEM_JSON).body(new ApiProblem("work-order.not-found", "Work order not found", "trace-contract-lab"));
        return ResponseEntity.ok(new WorkOrderResponse(id, "IN_PROGRESS", 3, null));
    }
}
