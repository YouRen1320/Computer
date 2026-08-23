package academy.openapi;

import java.util.Set;

/** Exercise starter deliberately forgets the directional response-required rule. */
public final class CompatibilityGate {
    private CompatibilityGate() {}
    public static boolean compatible(Set<String> oldRequired, Set<String> candidateRequired) { return true; }
}
