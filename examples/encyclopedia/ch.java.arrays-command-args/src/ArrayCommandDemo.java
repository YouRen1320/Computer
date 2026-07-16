public class ArrayCommandDemo {
    public static void main(String[] args) {
        int[] priorities = {3, 5, 2};
        int[] alias = priorities;
        alias[1] = 4;

        System.out.println("length=" + priorities.length);
        for (int i = 0; i < priorities.length; i++) {
            System.out.println("index=" + i + " value=" + priorities[i]);
        }

        int max = priorities[0];
        int foundIndex = -1;
        int urgent = 0;
        for (int i = 0; i < priorities.length; i++) {
            if (priorities[i] > max) {
                max = priorities[i];
            }
            if (priorities[i] == 4 && foundIndex == -1) {
                foundIndex = i;
            }
            if (priorities[i] >= 4) {
                urgent++;
            }
        }
        System.out.println("summary.max=" + max + " foundIndex=" + foundIndex + " urgent=" + urgent);

        String[][] shifts = {{"A01", "A02"}, {"B01"}, {}};
        System.out.println("matrix.rows=" + shifts.length + " lengths="
                + shifts[0].length + "," + shifts[1].length + "," + shifts[2].length);
        System.out.println("matrix.value=" + shifts[0][1]);

        System.out.println("args.count=" + args.length);
        if (args.length == 0) {
            System.out.println("args.values=EMPTY");
        } else {
            for (int i = 0; i < args.length; i++) {
                System.out.println("args[" + i + "]=" + args[i]);
            }
        }
    }
}
