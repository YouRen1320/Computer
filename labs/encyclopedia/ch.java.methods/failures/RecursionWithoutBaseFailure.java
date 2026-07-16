public class RecursionWithoutBaseFailure {
    static int countdown(int remaining) {
        return 1 + countdown(remaining + 1);
    }

    public static void main(String[] args) {
        System.out.println(countdown(1));
    }
}
