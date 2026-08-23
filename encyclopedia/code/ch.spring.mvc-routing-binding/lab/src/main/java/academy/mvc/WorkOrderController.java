package academy.mvc;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/work-orders")
public final class WorkOrderController {
    private final WorkOrderQuery query;

    public WorkOrderController(WorkOrderQuery query) {
        this.query = query;
    }

    @GetMapping("/{id}")
    public ResponseEntity<String> detail(
            @PathVariable("id") long id,
            @RequestHeader("X-Tenant-Id") String tenantId) {
        if (id <= 0 || tenantId.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        return query.find(id, tenantId)
                .map(body -> ResponseEntity.ok().header("X-Contract", "work-order-detail").body(body))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping
    public ResponseEntity<String> list(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size,
            @RequestHeader("X-Tenant-Id") String tenantId) {
        if (page < 0 || size < 1 || size > 100 || tenantId.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        return ResponseEntity.ok()
                .header("X-Contract", "work-order-page")
                .body(query.page(page, size, tenantId));
    }
}
