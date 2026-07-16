import java.util.Scanner;

public class InputBoundaryLab {
    static String readPair(Scanner scanner) {
        if (!scanner.hasNextLine()) {
            return "EOF";
        }
        String line = scanner.nextLine().trim();
        if (line.isEmpty()) {
            return "INVALID:field-count";
        }
        String[] fields = line.split("\\s+");
        if (fields.length != 2) {
            return "INVALID:field-count";
        }
        Integer price = parse(fields[0]);
        Integer quantity = parse(fields[1]);
        if (price == null || quantity == null) {
            return "INVALID:not-integer";
        }
        if (price <= 0 || quantity < 0) {
            return "INVALID:range";
        }
        return "OK:" + (price * quantity);
    }

    private static Integer parse(String text) {
        try {
            return Integer.valueOf(text);
        } catch (NumberFormatException ignored) {
            return null;
        }
    }
}
