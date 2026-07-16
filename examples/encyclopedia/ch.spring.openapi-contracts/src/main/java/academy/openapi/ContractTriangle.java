package academy.openapi;

import java.util.*;

/** Focused semantic gate: response promises may not shrink and accepted input may not narrow. */
public final class ContractTriangle {
    private ContractTriangle() {}
    public record Contract(Set<String> statuses, Set<String> responseRequired, int descriptionMaxLength) {
        public Contract { statuses = Set.copyOf(statuses); responseRequired = Set.copyOf(responseRequired); }
    }
    public static Contract baseline() { return new Contract(Set.of("200", "404"), Set.of("id", "status", "version"), 5000); }
    public static List<String> breakingChanges(Contract oldContract, Contract candidate) {
        var changes = new ArrayList<String>();
        oldContract.statuses().stream().filter(s -> !candidate.statuses().contains(s)).sorted().forEach(s -> changes.add("removed-status:" + s));
        oldContract.responseRequired().stream().filter(f -> !candidate.responseRequired().contains(f)).sorted().forEach(f -> changes.add("removed-required-response:" + f));
        if (candidate.descriptionMaxLength() < oldContract.descriptionMaxLength()) changes.add("tightened-request-maxLength");
        return List.copyOf(changes);
    }
    public static List<String> validateResponse(Contract contract, Map<String, Object> json) {
        return contract.responseRequired().stream().filter(field -> !json.containsKey(field)).sorted().map(field -> "missing:" + field).toList();
    }
}
