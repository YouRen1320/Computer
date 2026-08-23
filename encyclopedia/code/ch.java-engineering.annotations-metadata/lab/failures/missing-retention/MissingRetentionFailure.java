@interface MissingRetentionRule {
}

@MissingRetentionRule
public final class MissingRetentionFailure {
    public static void main(String[] args) {
        boolean present = MissingRetentionFailure.class.isAnnotationPresent(MissingRetentionRule.class);
        System.out.println("missing-retention-present=" + present);
        if (!present) {
            System.err.println("first-evidence=omitted @Retention defaults to CLASS, not RUNTIME");
            System.exit(8);
        }
    }
}
