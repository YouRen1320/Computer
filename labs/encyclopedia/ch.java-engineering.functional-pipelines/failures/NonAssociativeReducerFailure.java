public final class NonAssociativeReducerFailure {
    private NonAssociativeReducerFailure() {
    }

    public static void main(String[] args) {
        int leftGrouped = (10 - 3) - 2;
        int rightGrouped = 10 - (3 - 2);
        if (leftGrouped != rightGrouped) {
            throw new IllegalStateException("NON_ASSOCIATIVE_REDUCER left=" + leftGrouped
                    + " right=" + rightGrouped);
        }
    }
}
