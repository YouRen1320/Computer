public class ArrayBoundaryLab {
    public static void main(String[] args) {
        int[] empty = {};
        int traversed = 0;
        for (int ignored : empty) {
            traversed++;
        }
        System.out.println("empty.length=" + empty.length + " traversed=" + traversed);

        int[] one = {4};
        System.out.println("one.length=" + one.length + " first=" + one[0] + " last=" + one[one.length - 1]);

        int[] many = {3, 5, 4, 4};
        int max = many[0];
        int found4 = -1;
        int urgent = 0;
        for (int i = 0; i < many.length; i++) {
            if (many[i] > max) {
                max = many[i];
            }
            if (many[i] == 4 && found4 == -1) {
                found4 = i;
            }
            if (many[i] >= 4) {
                urgent++;
            }
        }
        System.out.println("many.length=" + many.length + " max=" + max + " found4=" + found4 + " urgent=" + urgent);

        int[] original = {3, 2};
        int[] alias = original;
        int aliasBefore = original[0];
        alias[0] = 5;
        System.out.println("alias.before=" + aliasBefore + " alias.after=" + alias[0] + " original=" + original[0]);

        int[] copy = new int[original.length];
        for (int i = 0; i < original.length; i++) {
            copy[i] = original[i];
        }
        copy[0] = 9;
        System.out.println("copy.changed=" + copy[0] + " original=" + original[0]);

        String[][] shifts = {{"A01", "A02"}, {"B01"}, {}};
        System.out.println("matrix.rows=" + shifts.length + " lengths="
                + shifts[0].length + "," + shifts[1].length + "," + shifts[2].length
                + " value=" + shifts[1][0]);

        System.out.println("args.count=" + args.length);
        if (args.length == 0) {
            System.out.println("args.summary=max=NONE sum=0");
        } else {
            int[] priorities = new int[args.length];
            int sum = 0;
            int argsMax = Integer.parseInt(args[0]);
            for (int i = 0; i < args.length; i++) {
                priorities[i] = Integer.parseInt(args[i]);
                sum += priorities[i];
                if (priorities[i] > argsMax) {
                    argsMax = priorities[i];
                }
            }
            System.out.println("args.summary=max=" + argsMax + " sum=" + sum);
        }
    }
}
