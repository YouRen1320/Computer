public class MethodsDemo {
    static int calculateTotalCents(int unitPriceCents, int quantity) {
        return unitPriceCents * quantity;
    }

    static String classifyPriority(int priority) {
        if (priority < 1 || priority > 5) return "INVALID";
        return priority >= 4 ? "URGENT" : "NORMAL";
    }

    static String ticketLabel(int id) {
        return "T-" + id;
    }

    static String ticketLabel(int id, String status) {
        return "T-" + id + ":" + status;
    }

    static void increase(int value) {
        value++;
    }

    static void markFirstUrgent(int[] priorities) {
        priorities[0] = 5;
    }

    static void replaceLocally(int[] priorities) {
        priorities = new int[]{9, 9};
    }

    static int countdownSteps(int remaining) {
        if (remaining <= 0) return 0;
        return 1 + countdownSteps(remaining - 1);
    }

    public static void main(String[] args) {
        System.out.println("total.zero=" + calculateTotalCents(1999, 0));
        System.out.println("total.multiple=" + calculateTotalCents(1999, 3));
        System.out.println("priority.3=" + classifyPriority(3));
        System.out.println("priority.5=" + classifyPriority(5));
        System.out.println("label.simple=" + ticketLabel(7));
        System.out.println("label.status=" + ticketLabel(7, "ASSIGNED"));

        int callerValue = 3;
        increase(callerValue);
        System.out.println("value.caller=" + callerValue);

        int[] callerArray = {2, 3};
        markFirstUrgent(callerArray);
        System.out.println("array.element=" + callerArray[0]);
        replaceLocally(callerArray);
        System.out.println("array.afterReassign=" + callerArray[0]);

        System.out.println("countdown.0=" + countdownSteps(0));
        System.out.println("countdown.1=" + countdownSteps(1));
        System.out.println("countdown.4=" + countdownSteps(4));
    }
}
