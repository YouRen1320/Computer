public class FallthroughFailure {
    public static void main(String[] args) {
        int stage = 1;
        int transitions = 0;
        switch (stage) {
            case 1:
                transitions++;
            case 2:
                transitions++;
                break;
            default:
                transitions = -1;
        }

        if (transitions != 1) {
            System.err.println("FALLTHROUGH_DETECTED expected=1 actual=" + transitions);
            System.exit(3);
        }
    }
}
