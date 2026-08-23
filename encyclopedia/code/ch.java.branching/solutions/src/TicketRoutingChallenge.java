public class TicketRoutingChallenge {
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
        System.out.println("priority.1=" + route);

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
        System.out.println("priority.3=" + route);

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
        System.out.println("priority.5=" + route);

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
        System.out.println("priority.0=" + route);

        String status = "ASSIGNED";
        String action = switch (status) {
            case "CREATED" -> "WAIT";
            case "ASSIGNED", "IN_PROGRESS" -> "WORK";
            case "CLOSED" -> "ARCHIVE";
            default -> "REJECT_UNKNOWN";
        };
        System.out.println("status.ASSIGNED=" + action);
    }
}
