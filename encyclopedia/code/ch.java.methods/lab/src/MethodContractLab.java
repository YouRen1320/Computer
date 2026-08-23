public class MethodContractLab {
    static int calculateTotalCents(int unitPriceCents, int quantity) {
        return unitPriceCents * quantity;
    }

    static int remaining(int capacity, int used) {
        return capacity - used;
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
        priorities = new int[]{9};
    }

    static int countdownSteps(int remaining) {
        if (remaining <= 0) return 0;
        return 1 + countdownSteps(remaining - 1);
    }

    public static void main(String[] args) {
        System.out.println("total.zero=" + calculateTotalCents(1999, 0)
                + " one=" + calculateTotalCents(1999, 1)
                + " three=" + calculateTotalCents(1999, 3));
        System.out.println("remaining.correct=" + remaining(10, 3) + " swapped=" + remaining(3, 10));
        System.out.println("classify.0=" + classifyPriority(0) + " classify.4=" + classifyPriority(4));
        System.out.println("label.simple=" + ticketLabel(7));
        System.out.println("label.status=" + ticketLabel(7, "ASSIGNED"));

        int callerValue = 3;
        increase(callerValue);
        System.out.println("pass.value.before=3 after=" + callerValue);
        int[] priorities = {2, 3};
        markFirstUrgent(priorities);
        System.out.println("pass.array.element=" + priorities[0]);
        replaceLocally(priorities);
        System.out.println("pass.reassign.element=" + priorities[0]);

        System.out.println("countdown.0=" + countdownSteps(0));
        System.out.println("countdown.1=" + countdownSteps(1));
        System.out.println("countdown.4=" + countdownSteps(4));
    }
}
