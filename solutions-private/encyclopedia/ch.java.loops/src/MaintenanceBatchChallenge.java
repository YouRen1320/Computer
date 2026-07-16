public class MaintenanceBatchChallenge {
    public static void main(String[] args) {
        int n = 5;
        int processed = 0;
        int skipped = 0;
        int stoppedAt = 0;
        int totalPriority = 0;

        for (int ticket = 1; ticket <= n; ticket++) {
            if (ticket == 2) {
                skipped++;
                continue;
            }
            if (ticket == 5) {
                stoppedAt = ticket;
                break;
            }
            processed++;
            totalPriority += ticket;
        }

        System.out.println("processed=" + processed);
        System.out.println("skipped=" + skipped);
        System.out.println("stoppedAt=" + stoppedAt);
        System.out.println("totalPriority=" + totalPriority);
    }
}
