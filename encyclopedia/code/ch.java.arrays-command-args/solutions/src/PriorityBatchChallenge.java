public class PriorityBatchChallenge {
    public static void main(String[] args) {
        int[] priorities = new int[args.length];
        for (int i = 0; i < args.length; i++) {
            priorities[i] = Integer.parseInt(args[i]);
        }

        int urgent = 0;
        int max = 0;
        if (priorities.length > 0) {
            max = priorities[0];
            for (int i = 0; i < priorities.length; i++) {
                if (priorities[i] > max) max = priorities[i];
                if (priorities[i] >= 4) urgent++;
            }
        }

        int first4 = -1;
        for (int i = 0; i < priorities.length; i++) {
            if (priorities[i] == 4) {
                first4 = i;
                break;
            }
        }

        System.out.println("count=" + priorities.length);
        System.out.println("max=" + (priorities.length == 0 ? "NONE" : max));
        System.out.println("urgent=" + urgent);
        System.out.println("first4=" + first4);
    }
}
