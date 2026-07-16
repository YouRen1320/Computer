public class NullDereferenceFailure {
    public static void main(String[] args) {
        StringBuilder note = null;
        note.append("unreachable");
    }
}
