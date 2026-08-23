public class WorkOrderMethodsChallenge {
    static int calculateTotalCents(int unitPriceCents, int quantity) {
        return unitPriceCents + quantity; // TODO 1：金额公式。
    }

    static int remaining(int capacity, int used) {
        return capacity - used;
    }

    static void markFirstUrgent(int[] priorities) {
        priorities = new int[]{5, 3}; // TODO 3：重新给形参赋值不会改调用者元素。
    }

    static int countdownSteps(int remaining) {
        if (remaining <= 1) return 0; // TODO 4：0 是基线，1 仍应贡献一步。
        return 1 + countdownSteps(remaining - 1);
    }

    public static void main(String[] args) {
        System.out.println("total=" + calculateTotalCents(1999, 3));
        System.out.println("remaining=" + remaining(3, 10)); // TODO 2：实参角色顺序。
        int[] priorities = {2, 3};
        markFirstUrgent(priorities);
        System.out.println("first=" + priorities[0]);
        System.out.println("countdown=" + countdownSteps(4));
    }
}
