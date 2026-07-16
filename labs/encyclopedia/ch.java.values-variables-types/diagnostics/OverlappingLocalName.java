public class OverlappingLocalName {
    public static void main(String[] args) {
        int openTicketCount = 2;

        {
            int openTicketCount = 3;
            System.out.println(openTicketCount);
        }
    }
}
