public class TicketRoutingChallenge {
    public static void main(String[] args) {
        int priority = 1;
        String route;
        if (priority < 0 || priority > 5) { // TODO 1: 修复合法下界
            route = "REJECTED";
        } else if (priority > 5) { // TODO 2: 修复最高优先级条件
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("priority.1=" + route);

        priority = 3;
        if (priority < 0 || priority > 5) { // TODO 1: 同类下界需一致修复
            route = "REJECTED";
        } else if (priority > 5) { // TODO 2: 同类最高级条件需一致修复
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("priority.3=" + route);

        priority = 5;
        if (priority < 0 || priority > 5) { // TODO 1
            route = "REJECTED";
        } else if (priority > 5) { // TODO 2
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("priority.5=" + route);

        priority = 0;
        if (priority < 0 || priority > 5) { // TODO 1
            route = "REJECTED";
        } else if (priority > 5) { // TODO 2
            route = "CRITICAL";
        } else if (priority >= 3) {
            route = "HIGH";
        } else {
            route = "ROUTINE";
        }
        System.out.println("priority.0=" + route);

        String status = "ASSIGNED";
        String action = switch (status) {
            case "CREATED", "ASSIGNED" -> "WAIT"; // TODO 3: 修复 ASSIGNED 的动作
            case "IN_PROGRESS" -> "WORK";
            case "CLOSED" -> "ARCHIVE";
            default -> "REJECT_UNKNOWN";
        };
        System.out.println("status.ASSIGNED=" + action);
    }
}
