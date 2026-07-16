package academy.usecases.web;

import academy.usecases.application.AssignWorkOrderUseCase;
import academy.usecases.application.AssignWorkOrderUseCase.AssignCommand;

/** Protocol adapter maps trusted authentication context and request fields to the use-case input. */
public final class AssignWorkOrderController {
    private final AssignWorkOrderUseCase useCase;
    public AssignWorkOrderController(AssignWorkOrderUseCase useCase){this.useCase=useCase;}
    public Response post(AuthContext auth,String workOrderId,Request request){var result=useCase.assign(new AssignCommand(auth.tenantId(),auth.actorId(),workOrderId,request.teamId(),request.technicianId(),request.expectedVersion()));return new Response(result.workOrderId(),result.state(),result.version());}
    public record AuthContext(String tenantId,String actorId){} public record Request(String teamId,String technicianId,long expectedVersion){} public record Response(String id,String state,long version){}
}
