public class LoopBoundaryOracle {
    public static void main(String[] args) {
        int assertions = 0;

        int count = 0;
        int sum = 0;
        for (int i = 1; i <= 0; i++) {
            count++;
            sum += i;
        }
        assert count == 0;
        assertions++;
        assert sum == 0;
        assertions++;

        count = 0;
        sum = 0;
        for (int i = 1; i <= 1; i++) {
            count++;
            sum += i;
        }
        assert count == 1;
        assertions++;
        assert sum == 1;
        assertions++;

        count = 0;
        sum = 0;
        for (int i = 1; i <= 4; i++) {
            count++;
            sum += i;
        }
        assert count == 4;
        assertions++;
        assert sum == 10;
        assertions++;

        int remaining = 3;
        int steps = 0;
        while (remaining > 0) {
            remaining--;
            steps++;
        }
        assert steps == 3;
        assertions++;
        assert remaining == 0;
        assertions++;

        int attempts = 0;
        do {
            attempts++;
        } while (attempts < 0);
        assert attempts == 1;
        assertions++;

        int sentinel = 3;
        while (sentinel != 0) {
            sentinel--;
        }
        assert sentinel == 0;
        assertions++;

        System.out.println("assertions=" + assertions + " passed");
    }
}
