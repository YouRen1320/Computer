import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;

@Retention(RetentionPolicy.SOURCE)
@interface RuntimeRule {
}

@RuntimeRule
public final class SourceRetentionFailure {
    public static void main(String[] args) {
        boolean present = SourceRetentionFailure.class.isAnnotationPresent(RuntimeRule.class);
        System.out.println("source-retention-present=" + present);
        if (!present) {
            System.err.println("first-evidence=runtime probe could not see SOURCE annotation");
            System.exit(7);
        }
    }
}
