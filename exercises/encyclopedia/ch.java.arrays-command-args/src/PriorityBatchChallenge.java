public class PriorityBatchChallenge {
    public static void main(String[] args) {
        int[] priorities = new int[args.length];
        for (int i = 1; i < args.length; i++) { // TODO 1：从哪个索引开始才不会漏首项？
            priorities[i] = Integer.parseInt(args[i]);
        }

        int max = 0; // TODO 2：空数组应输出 NONE；非空最大值应来自真实元素。
        int urgent = 0;
        for (int i = 0; i < priorities.length; i++) {
            if (priorities[i] > max) max = priorities[i];
            if (priorities[i] > 4) urgent++; // TODO 3：紧急边界包含 4。
        }

        int first4 = -1;
        for (int i = 0; i < priorities.length; i++) {
            if (priorities[i] == 4) {
                first4 = i;
                // TODO 4：找到第一个匹配后应立即结束查找。
            }
        }

        System.out.println("count=" + priorities.length);
        System.out.println("max=" + max);
        System.out.println("urgent=" + urgent);
        System.out.println("first4=" + first4);
    }
}
