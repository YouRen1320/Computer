public class OutOfScope {
    public static void main(String[] args) {
        {
            String displaySection = "设备摘要";
            System.out.println(displaySection);
        }

        System.out.println(displaySection);
    }
}
