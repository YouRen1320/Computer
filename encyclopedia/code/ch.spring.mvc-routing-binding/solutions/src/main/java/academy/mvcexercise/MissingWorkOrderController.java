package academy.mvcexercise;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/work-orders")
public final class MissingWorkOrderController {

    @GetMapping("/{id}")
    public ResponseEntity<String> detail(
            @PathVariable("id") long id,
            @RequestHeader("X-Tenant-Id") String tenantId) {
        if (id == 42 && "tenant-a".equals(tenantId)) {
            return ResponseEntity.ok("WO-42:CREATED");
        }
        return ResponseEntity.notFound().build();
    }
}
