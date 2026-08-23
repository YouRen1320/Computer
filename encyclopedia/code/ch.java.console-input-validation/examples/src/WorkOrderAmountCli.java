import java.util.Scanner;

public class WorkOrderAmountCli {
    private static final int EXIT_USAGE = 64;
    private static final int EXIT_DATA = 65;
    private static final int EXIT_EOF = 66;

    public static void main(String[] args) {
        int status = run(args, new Scanner(System.in));
        if (status != 0) {
            System.exit(status);
        }
    }

    static int run(String[] args, Scanner scanner) {
        String[] fields;
        if (args.length == 2) {
            fields = args;
        } else if (args.length == 0) {
            if (!scanner.hasNextLine()) {
                System.err.println("ERROR EOF: expected unitPriceCents quantity");
                return EXIT_EOF;
            }
            String line = scanner.nextLine().trim();
            fields = line.isEmpty() ? new String[0] : line.split("\\s+");
        } else {
            System.err.println("ERROR USAGE: expected exactly 2 arguments");
            return EXIT_USAGE;
        }

        if (fields.length != 2) {
            System.err.println("ERROR USAGE: expected unitPriceCents quantity");
            return EXIT_USAGE;
        }

        Integer unitPriceCents = parseInteger(fields[0]);
        Integer quantity = parseInteger(fields[1]);
        if (unitPriceCents == null || quantity == null) {
            System.err.println("ERROR DATA: both values must be integers");
            return EXIT_DATA;
        }
        if (unitPriceCents <= 0 || quantity < 0) {
            System.err.println("ERROR DATA: price must be positive and quantity non-negative");
            return EXIT_DATA;
        }

        System.out.println("totalCents=" + (unitPriceCents * quantity));
        return 0;
    }

    private static Integer parseInteger(String text) {
        try {
            return Integer.valueOf(text);
        } catch (NumberFormatException ignored) {
            return null;
        }
    }
}
