import java.util.Scanner;

public class InputBoundaryOracle {
    public static void main(String[] args) {
        check("OK:5997", "1999 3\n");
        check("OK:0", "1999 0\n");
        check("INVALID:not-integer", "abc 3\n");
        check("INVALID:range", "1999 -1\n");
        check("INVALID:field-count", "\n");
        check("EOF", "");
        System.out.println("assertions=6 passed");
    }

    private static void check(String expected, String input) {
        String actual = InputBoundaryLab.readPair(new Scanner(input));
        if (!expected.equals(actual)) {
            throw new AssertionError("expected=" + expected + " actual=" + actual);
        }
    }
}
