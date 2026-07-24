package academy.openapi;

import java.util.*;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class ContractTriangleTest {
    @Test void runtimeResponseSatisfiesRequiredPromise() { assertThat(ContractTriangle.validateResponse(ContractTriangle.baseline(), Map.of("id","wo-1","status","CREATED","version",0))).isEmpty(); }
    @Test void exampleMissingRequiredFieldIsRejected() { assertThat(ContractTriangle.validateResponse(ContractTriangle.baseline(), Map.of("id","wo-1","status","CREATED"))).containsExactly("missing:version"); }
    @Test void identicalCandidateIsCompatible() { assertThat(ContractTriangle.breakingChanges(ContractTriangle.baseline(), ContractTriangle.baseline())).isEmpty(); }
    @Test void optionalResponseFieldIsCompatible() { var old = ContractTriangle.baseline(); var next = new ContractTriangle.Contract(old.statuses(), old.responseRequired(), old.descriptionMaxLength()); assertThat(ContractTriangle.breakingChanges(old,next)).isEmpty(); }
    @Test void deletingRequiredResponseFieldBreaksConsumers() { var old=ContractTriangle.baseline(); var next=new ContractTriangle.Contract(old.statuses(),Set.of("id","status"),5000); assertThat(ContractTriangle.breakingChanges(old,next)).containsExactly("removed-required-response:version"); }
    @Test void deletingStatusBreaksConsumers() { var old=ContractTriangle.baseline(); var next=new ContractTriangle.Contract(Set.of("200"),old.responseRequired(),5000); assertThat(ContractTriangle.breakingChanges(old,next)).containsExactly("removed-status:404"); }
    @Test void wideningAcceptedInputIsCompatible() { var old=ContractTriangle.baseline(); var next=new ContractTriangle.Contract(old.statuses(),old.responseRequired(),8000); assertThat(ContractTriangle.breakingChanges(old,next)).isEmpty(); }
    @Test void tighteningAcceptedInputIsBreaking() { var old=ContractTriangle.baseline(); var next=new ContractTriangle.Contract(old.statuses(),old.responseRequired(),1000); assertThat(ContractTriangle.breakingChanges(old,next)).containsExactly("tightened-request-maxLength"); }
}
