public class WorkOrderMethodsChallenge {
    static int calculateTotalCents(int unitPriceCents, int quantity) {
        return unitPriceCents * quantity;
    }

    static int remaining(int capacity, int used) {
        return capacity - used;
    }

    static void markFirstUrgent(int[] priorities) {
        priorities[0] = 5;
    }

    static int countdownSteps(int remaining) {
        if (remaining <= 0) return 0;
        return 1 + countdownSteps(remaining - 1);
    }

    public static void main(String[] args) {
        System.out.println("total=" + calculateTotalCents(1999, 3));
        System.out.println("remaining=" + remaining(10, 3));
        int[] priorities = {2, 3};
        markFirstUrgent(priorities);
        System.out.println("first=" + priorities[0]);
        System.out.println("countdown=" + countdownSteps(4));
    }
}
