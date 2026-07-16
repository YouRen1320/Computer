public class PriorityRoutingLab {
    public static void main(String[] args) {
        int priority = 1;
        String route;
        if (priority < 1 || priority > 5) {
            route = "REJECTED";
        } else if (priority == 5) {
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("min=" + route);

        priority = 3;
        if (priority < 1 || priority > 5) {
            route = "REJECTED";
        } else if (priority == 5) {
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("middle=" + route);

        priority = 5;
        if (priority < 1 || priority > 5) {
            route = "REJECTED";
        } else if (priority == 5) {
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("max=" + route);

        priority = 0;
        if (priority < 1 || priority > 5) {
            route = "REJECTED";
        } else if (priority == 5) {
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("invalidLow=" + route);

        priority = 6;
        if (priority < 1 || priority > 5) {
            route = "REJECTED";
        } else if (priority == 5) {
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("invalidHigh=" + route);

        String status = "ASSIGNED";
        String action = switch (status) {
            case "CREATED" -> "WAIT";
            case "ASSIGNED", "IN_PROGRESS" -> "WORK";
            case "CLOSED" -> "ARCHIVE";
            default -> "REJECT_UNKNOWN";
        };
        System.out.println("status=" + action);
    }
}
