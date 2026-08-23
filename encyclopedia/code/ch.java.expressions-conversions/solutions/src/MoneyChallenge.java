public class MoneyChallenge {
    public static void main(String[] args) {
        int unitPriceCents = 2_500;
        int quantity = 3;
        int serviceFeeCents = 1;
        int groups = 4;

        long totalCents = (long) unitPriceCents * quantity + serviceFeeCents;
        long eachCents = totalCents / groups;
        long remainderCents = totalCents % groups;
        boolean conserved = eachCents * groups + remainderCents == totalCents;

        System.out.println("totalCents=" + totalCents);
        System.out.println("eachCents=" + eachCents);
        System.out.println("remainderCents=" + remainderCents);
        System.out.println("conserved=" + conserved);
    }
}
