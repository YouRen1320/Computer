public class EagerBooleanFailure {
    public static void main(String[] args) {
        int divisor = 0;
        boolean result = false & (10 / divisor > 1);
        System.out.println(result);
    }
}
