package academy.openapi;

import java.util.Set;

/** Reference solution preserves every response field promised as required by the baseline. */
public final class CompatibilityGate {
    private CompatibilityGate() {}
    public static boolean compatible(Set<String> oldRequired, Set<String> candidateRequired) { return candidateRequired.containsAll(oldRequired); }
}
