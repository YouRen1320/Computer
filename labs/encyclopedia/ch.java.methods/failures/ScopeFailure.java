public class ScopeFailure {
    public static void main(String[] args) {
        if (args.length == 0) {
            int localCount = 0;
        }
        System.out.println(localCount);
    }
}
