public class NonTerminatingProbe {
    public static void main(String[] args) {
        int remaining = 3;
        int safetySteps = 0;

        while (remaining > 0) {
            safetySteps++;
            // 故意遗漏 remaining--，真实代码会永不终止。
            if (safetySteps == 4) {
                System.err.println("NON_TERMINATING_GUARD remaining=" + remaining + " safetySteps=" + safetySteps);
                System.exit(4);
            }
        }
    }
}
