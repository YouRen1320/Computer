public class MoneyChallenge {
    public static void main(String[] args) {
        int unitPriceCents = 2_500;
        int quantity = 3;
        int serviceFeeCents = 1;
        int groups = 4;

        long totalCents = 0L;
        long eachCents = 0L;
        long remainderCents = 0L;
        boolean conserved = false;

        System.out.println("totalCents=" + totalCents);
        System.out.println("eachCents=" + eachCents);
        System.out.println("remainderCents=" + remainderCents);
        System.out.println("conserved=" + conserved);
    }
}
