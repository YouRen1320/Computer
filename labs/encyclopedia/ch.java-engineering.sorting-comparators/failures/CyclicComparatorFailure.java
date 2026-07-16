import java.util.Comparator;

public final class CyclicComparatorFailure {
    private CyclicComparatorFailure() {
    }

    public static void main(String[] args) {
        Comparator<Token> cyclic = (left, right) -> {
            if (left == right) {
                return 0;
            }
            return switch (left) {
                case A -> right == Token.B ? 1 : -1;
                case B -> right == Token.C ? 1 : -1;
                case C -> right == Token.A ? 1 : -1;
            };
        };
        if (cyclic.compare(Token.A, Token.B) > 0
                && cyclic.compare(Token.B, Token.C) > 0
                && cyclic.compare(Token.A, Token.C) < 0) {
            throw new IllegalStateException("CYCLIC_ORDER");
        }
    }

    private enum Token {
        A, B, C
    }
}
