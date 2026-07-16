import java.util.Scanner;

public class RepairIntakeOracle {
    public static void main(String[] args) {
        check("OK:accepted priority=5 description=motor alarm", new String[]{"5", "motor alarm"}, "");
        check("OK:accepted priority=3 description=temperature high", new String[0], "3 temperature high\n");
        check("64:ERROR USAGE", new String[]{"3"}, "");
        check("65:ERROR DATA", new String[]{"x", "alarm"}, "");
        check("65:ERROR DATA", new String[]{"0", "alarm"}, "");
        check("65:ERROR DATA", new String[0], "\n");
        check("66:ERROR EOF", new String[0], "");
        System.out.println("assertions=7 passed");
    }

    private static void check(String expected, String[] args, String input) {
        String actual = RepairIntakeSolution.evaluate(args, new Scanner(input));
        if (!expected.equals(actual)) throw new AssertionError("expected=" + expected + " actual=" + actual);
    }
}
