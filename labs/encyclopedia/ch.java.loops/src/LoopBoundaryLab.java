public class LoopBoundaryLab {
    public static void main(String[] args) {
        int count = 0;
        int sum = 0;
        for (int i = 1; i <= 0; i++) {
            count++;
            sum += i;
        }
        System.out.println("n0.count=" + count + " sum=" + sum);

        count = 0;
        sum = 0;
        for (int i = 1; i <= 1; i++) {
            count++;
            sum += i;
        }
        System.out.println("n1.count=" + count + " sum=" + sum);

        count = 0;
        sum = 0;
        for (int i = 1; i <= 4; i++) {
            count++;
            sum += i;
        }
        System.out.println("n4.count=" + count + " sum=" + sum);

        int remaining = 3;
        int steps = 0;
        while (remaining > 0) {
            remaining--;
            steps++;
        }
        System.out.println("while.steps=" + steps + " remaining=" + remaining);

        int attempts = 0;
        do {
            attempts++;
        } while (attempts < 0);
        System.out.println("doWhile.attempts=" + attempts);

        int sentinel = 3;
        int handled = 0;
        while (sentinel != 0) {
            handled++;
            sentinel--;
        }
        System.out.println("sentinel.handled=" + handled + " value=" + sentinel);

        int processed = 0;
        int skipped = 0;
        int stoppedAt = 0;
        int priorityTotal = 0;
        for (int ticket = 1; ticket <= 5; ticket++) {
            if (ticket == 2) {
                skipped++;
                continue;
            }
            if (ticket == 5) {
                stoppedAt = ticket;
                break;
            }
            processed++;
            priorityTotal += ticket;
        }
        System.out.println("control.processed=" + processed + " skipped=" + skipped
                + " stoppedAt=" + stoppedAt + " sum=" + priorityTotal);
    }
}
