public class MissingUpdateProbe {
    public static void main(String[] args) {
        int sentinel = 2;
        int safetySteps = 0;
        while (sentinel != 0) {
            safetySteps++;
            if (safetySteps == 5) {
                System.err.println("LOOP_BUDGET_EXCEEDED sentinel=" + sentinel + " safetySteps=" + safetySteps);
                System.exit(5);
            }
        }
    }
}
