public class LoopsDemo {
    public static void main(String[] args) {
        int sum = 0;
        for (int i = 1; i <= 3; i++) {
            System.out.println("for.tick=" + i);
            sum += i;
        }
        System.out.println("for.sum=" + sum);

        int remaining = 3;
        int whileSteps = 0;
        while (remaining > 0) {
            remaining--;
            whileSteps++;
        }
        System.out.println("while.steps=" + whileSteps + " remaining=" + remaining);

        int attempts = 0;
        do {
            attempts++;
        } while (attempts < 1);
        System.out.println("doWhile.attempts=" + attempts);

        int nextTicket = 3;
        int sentinelProcessed = 0;
        while (nextTicket != 0) {
            sentinelProcessed++;
            nextTicket--;
        }
        System.out.println("sentinel.processed=" + sentinelProcessed + " value=" + nextTicket);

        int accepted = 0;
        int stoppedAt = 0;
        for (int ticket = 1; ticket <= 6; ticket++) {
            if (ticket == 2) {
                continue;
            }
            if (ticket == 5) {
                stoppedAt = ticket;
                break;
            }
            accepted++;
        }
        System.out.println("control.accepted=" + accepted + " stoppedAt=" + stoppedAt);
    }
}
