public class ExpressionsDemo {
    public static void main(String[] args) {
        int precedence = 2 + 3 * 4;
        int parenthesized = (2 + 3) * 4;

        int zero = 0;
        boolean shortCircuited = false && (10 / zero > 1);
        boolean comparison = 1_999 * 3 == 5_997;

        byte left = 40;
        byte right = 2;
        int promoted = left + right;

        int integerDivision = 5 / 2;
        double widenedAfterDivision = 5 / 2;
        double floatingDivision = 5.0 / 2;
        int negativeDivision = -7 / 3;
        int negativeRemainder = -7 % 3;

        long outsideInt = 3_000_000_000L;
        int narrowed = (int) outsideInt;

        int largeUnitPriceCents = 1_073_741_824;
        int rawOverflow = largeUnitPriceCents * 2;
        long widenedBeforeMultiply = (long) largeUnitPriceCents * 2;

        int totalCents = 1_000;
        int groups = 3;
        int eachCents = totalCents / groups;
        int remainderCents = totalCents % groups;

        System.out.println("precedence=" + precedence);
        System.out.println("parenthesized=" + parenthesized);
        System.out.println("shortCircuited=" + shortCircuited);
        System.out.println("comparison=" + comparison);
        System.out.println("promotedByteSum=" + promoted);
        System.out.println("integerDivision=" + integerDivision);
        System.out.println("widenedAfterDivision=" + widenedAfterDivision);
        System.out.println("floatingDivision=" + floatingDivision);
        System.out.println("negativeDivision=" + negativeDivision);
        System.out.println("negativeRemainder=" + negativeRemainder);
        System.out.println("narrowed=" + narrowed);
        System.out.println("rawOverflow=" + rawOverflow);
        System.out.println("widenedBeforeMultiply=" + widenedBeforeMultiply);
        System.out.println("splitEach=" + eachCents);
        System.out.println("splitRemainder=" + remainderCents);
        System.out.println("stringTrap=" + 1 + 2);
        System.out.println("stringGrouped=" + (1 + 2));
    }
}
