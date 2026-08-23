public class NullPathFailure {
    public static void main(String[] args) {
        StringBuilder deviceLabel = null;
        System.out.println(deviceLabel.length());
    }
}
