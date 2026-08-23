public class ArrayBoundaryOracle {
    public static void main(String[] args) {
        int assertions = 0;

        int[] empty = {};
        assert empty.length == 0;
        assertions++;

        int[] one = {4};
        assert one.length == 1;
        assertions++;
        assert one[0] == 4;
        assertions++;

        int[] many = {3, 5, 4, 4};
        assert many.length == 4;
        assertions++;
        int count = 0;
        int sum = 0;
        int max = many[0];
        int found4 = -1;
        for (int i = 0; i < many.length; i++) {
            count++;
            sum += many[i];
            if (many[i] > max) max = many[i];
            if (many[i] == 4 && found4 == -1) found4 = i;
        }
        assert count == 4;
        assertions++;
        assert sum == 16;
        assertions++;
        assert max == 5;
        assertions++;
        assert found4 == 2;
        assertions++;

        int[] original = {3, 2};
        int[] alias = original;
        alias[0] = 5;
        assert original[0] == 5;
        assertions++;
        int[] copy = new int[original.length];
        for (int i = 0; i < original.length; i++) copy[i] = original[i];
        copy[0] = 9;
        assert original[0] == 5;
        assertions++;

        String[][] shifts = {{"A01", "A02"}, {"B01"}, {}};
        assert shifts.length == 3;
        assertions++;
        assert shifts[0].length == 2;
        assertions++;
        assert shifts[1].length == 1;
        assertions++;
        assert shifts[2].length == 0;
        assertions++;

        System.out.println("assertions=" + assertions + " passed");
    }
}
