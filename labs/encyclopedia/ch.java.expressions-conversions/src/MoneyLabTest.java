public class MoneyLabTest {
    public static void main(String[] args) {
        int normalUnitCents = 1_999;
        int normalQuantity = 3;
        long normalTotal = (long) normalUnitCents * normalQuantity;
        assert normalTotal == 5_997L : "normalTotal=" + normalTotal;

        long zeroTotal = (long) normalUnitCents * 0;
        assert zeroTotal == 0L : "zeroTotal=" + zeroTotal;

        int nearLimitUnitCents = 1_073_741_823;
        long nearLimitTotal = (long) nearLimitUnitCents * 2;
        assert nearLimitTotal == 2_147_483_646L : "nearLimitTotal=" + nearLimitTotal;

        int overflowingUnitCents = 1_073_741_824;
        int rawOverflow = overflowingUnitCents * 2;
        assert rawOverflow == Integer.MIN_VALUE : "rawOverflow=" + rawOverflow;

        long widenedBeforeMultiply = (long) overflowingUnitCents * 2;
        assert widenedBeforeMultiply == 2_147_483_648L : "widenedBeforeMultiply=" + widenedBeforeMultiply;

        long totalCents = 5_997L;
        int groups = 4;
        long eachCents = totalCents / groups;
        long remainderCents = totalCents % groups;
        assert eachCents == 1_499L : "eachCents=" + eachCents;
        assert remainderCents == 1L : "remainderCents=" + remainderCents;
        assert eachCents * groups + remainderCents == totalCents : "allocation does not conserve cents";

        System.out.println("assertions=8 passed");
    }
}
