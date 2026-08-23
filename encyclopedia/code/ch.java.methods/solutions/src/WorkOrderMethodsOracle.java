public class WorkOrderMethodsOracle {
    public static void main(String[] args) {
        int assertions = 0;
        assert WorkOrderMethodsChallenge.calculateTotalCents(1999, 0) == 0;
        assertions++;
        assert WorkOrderMethodsChallenge.calculateTotalCents(1999, 1) == 1999;
        assertions++;
        assert WorkOrderMethodsChallenge.calculateTotalCents(1999, 3) == 5997;
        assertions++;
        assert WorkOrderMethodsChallenge.remaining(10, 3) == 7;
        assertions++;
        int[] priorities = {2, 3};
        WorkOrderMethodsChallenge.markFirstUrgent(priorities);
        assert priorities[0] == 5;
        assertions++;
        assert WorkOrderMethodsChallenge.countdownSteps(0) == 0;
        assertions++;
        assert WorkOrderMethodsChallenge.countdownSteps(1) == 1;
        assertions++;
        assert WorkOrderMethodsChallenge.countdownSteps(4) == 4;
        assertions++;
        System.out.println("assertions=" + assertions + " passed");
    }
}
