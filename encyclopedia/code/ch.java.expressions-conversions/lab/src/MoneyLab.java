public class MoneyLab {
    public static void main(String[] args) {
        int unitPriceCents = 1_999;
        int quantity = 3;
        long totalCents = (long) unitPriceCents * quantity;

        int allocationGroups = 4;
        long eachCents = totalCents / allocationGroups;
        long remainderCents = totalCents % allocationGroups;

        System.out.println("unitPriceCents=" + unitPriceCents);
        System.out.println("quantity=" + quantity);
        System.out.println("totalCents=" + totalCents);
        System.out.println("allocationEachCents=" + eachCents);
        System.out.println("allocationRemainderCents=" + remainderCents);
    }
}
