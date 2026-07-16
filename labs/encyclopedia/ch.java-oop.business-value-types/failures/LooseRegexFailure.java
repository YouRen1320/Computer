import java.util.regex.Pattern;

public final class LooseRegexFailure {
    private LooseRegexFailure() {
    }

    public static void main(String[] args) {
        boolean accepted = Pattern.compile("WO-.*").matcher("WO-").matches();
        if (accepted) {
            System.err.println("LOOSE_REGEX_ACCEPTED input=WO- expected=false actual=true");
            System.exit(7);
        }
        throw new AssertionError("fixture did not accept the invalid identifier");
    }
}
