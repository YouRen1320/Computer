public class AmbiguousOverloadFailure {
    static String route(int first, long second) {
        return "A";
    }

    static String route(long first, int second) {
        return "B";
    }

    public static void main(String[] args) {
        System.out.println(route(1, 1));
    }
}
