public class IdentityMistakeFailure {
    public static void main(String[] args) {
        String left = new String("PUMP-01");
        String right = new String("PUMP-01");

        if (left != right) {
            System.err.println("IDENTITY_MISTAKE sameText=true sameIdentity=false");
            System.exit(3);
        }
    }
}
