import java.util.Scanner;

public class RepairIntakeSolution {
    public static void main(String[] args) {
        String result = evaluate(args, new Scanner(System.in));
        if (result.startsWith("OK:")) {
            System.out.println(result.substring(3));
            return;
        }
        String[] parts = result.split(":", 2);
        System.err.println(parts[1]);
        System.exit(Integer.parseInt(parts[0]));
    }

    static String evaluate(String[] args, Scanner scanner) {
        String[] fields;
        if (args.length == 2) {
            fields = args;
        } else if (args.length == 0) {
            if (!scanner.hasNextLine()) return "66:ERROR EOF";
            String line = scanner.nextLine().trim();
            fields = line.isEmpty() ? new String[0] : line.split("\\s+", 2);
        } else {
            return "64:ERROR USAGE";
        }
        if (fields.length != 2) return "65:ERROR DATA";
        Integer priority = parse(fields[0]);
        String description = fields[1].trim();
        if (priority == null || description.isEmpty()) return "65:ERROR DATA";
        return "OK:accepted priority=" + priority + " description=" + description;
    }

    private static Integer parse(String text) {
        try {
            int value = Integer.parseInt(text);
            return value >= 1 && value <= 5 ? value : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }
}
