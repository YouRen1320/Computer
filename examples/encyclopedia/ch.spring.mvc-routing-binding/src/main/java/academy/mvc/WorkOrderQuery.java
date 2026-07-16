package academy.mvc;

import java.util.Optional;

public interface WorkOrderQuery {
    Optional<String> find(long id, String tenantId);
    String page(int page, int size, String tenantId);
}
