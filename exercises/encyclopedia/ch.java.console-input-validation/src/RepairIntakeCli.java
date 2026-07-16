import java.util.Scanner;

public class RepairIntakeCli {
    public static void main(String[] args) {
        int status = run(args, new Scanner(System.in));
        if (status != 0) System.exit(status);
    }

    static int run(String[] args, Scanner scanner) {
        String priorityText;
        String description;
        if (args.length == 2) {
            priorityText = args[0];
            description = args[1].trim();
        } else if (args.length == 0) {
            if (!scanner.hasNextLine()) {
                System.err.println("ERROR EOF");
                return 66;
            }
            String line = scanner.nextLine().trim();
            String[] fields = line.split("\\s+", 2);
            if (line.isEmpty() || fields.length != 2) {
                System.err.println("ERROR DATA");
                return 65;
            }
            priorityText = fields[0];
            description = fields[1].trim();
        } else {
            System.err.println("ERROR USAGE");
            return 64;
        }
        Integer priority = parsePriority(priorityText);
        if (priority == null || description.isEmpty()) {
            System.err.println("ERROR DATA");
            return 65;
        }
        System.out.println("accepted priority=" + priority + " description=" + description);
        return 0;
    }

    private static Integer parsePriority(String text) {
        try {
            int value = Integer.parseInt(text);
            return value >= 1 && value <= 5 ? value : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }
}
