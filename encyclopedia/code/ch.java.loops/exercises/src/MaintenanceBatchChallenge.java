public class MaintenanceBatchChallenge {
    public static void main(String[] args) {
        int n = 5;
        int processed = 0;
        int skipped = 0;
        int stoppedAt = 0;
        int totalPriority = 0;

        for (int ticket = 0; ticket <= n; ticket++) { // TODO 1: 修复起始边界
            if (ticket == 2) {
                skipped++;
                continue;
            }
            if (ticket > n) { // TODO 2: 在编号 5 进入处理前停止
                stoppedAt = ticket;
                break;
            }
            processed--; // TODO 3: 每处理一项应怎样更新计数器
            totalPriority += ticket;
        }

        System.out.println("processed=" + processed);
        System.out.println("skipped=" + skipped);
        System.out.println("stoppedAt=" + stoppedAt);
        System.out.println("totalPriority=" + totalPriority);
    }
}
