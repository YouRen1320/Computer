package academy.ioc;

import org.springframework.beans.factory.annotation.Autowired;

/**
 * Deliberate counterexample: the required collaborator is invisible in the constructor.
 */
public final class FieldInjectedService {
    @Autowired
    private WorkOrderGraph.WorkOrderRepository repository;

    public void open(String equipmentId) {
        repository.save(equipmentId);
    }

    public boolean wired() {
        return repository != null;
    }
}
