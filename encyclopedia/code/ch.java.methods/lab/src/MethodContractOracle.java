public class MethodContractOracle {
    public static void main(String[] args) {
        int assertions = 0;

        assert MethodContractLab.calculateTotalCents(1999, 0) == 0;
        assertions++;
        assert MethodContractLab.calculateTotalCents(1999, 1) == 1999;
        assertions++;
        assert MethodContractLab.calculateTotalCents(1999, 3) == 5997;
        assertions++;
        assert MethodContractLab.remaining(10, 3) == 7;
        assertions++;
        assert MethodContractLab.remaining(3, 10) == -7;
        assertions++;

        assert MethodContractLab.classifyPriority(0).equals("INVALID");
        assertions++;
        assert MethodContractLab.classifyPriority(1).equals("NORMAL");
        assertions++;
        assert MethodContractLab.classifyPriority(4).equals("URGENT");
        assertions++;
        assert MethodContractLab.classifyPriority(6).equals("INVALID");
        assertions++;

        assert MethodContractLab.ticketLabel(7).equals("T-7");
        assertions++;
        assert MethodContractLab.ticketLabel(7, "ASSIGNED").equals("T-7:ASSIGNED");
        assertions++;

        int value = 3;
        MethodContractLab.increase(value);
        assert value == 3;
        assertions++;
        int[] priorities = {2, 3};
        MethodContractLab.markFirstUrgent(priorities);
        assert priorities[0] == 5;
        assertions++;
        MethodContractLab.replaceLocally(priorities);
        assert priorities[0] == 5;
        assertions++;

        assert MethodContractLab.countdownSteps(-1) == 0;
        assertions++;
        assert MethodContractLab.countdownSteps(0) == 0;
        assertions++;
        assert MethodContractLab.countdownSteps(1) == 1;
        assertions++;
        assert MethodContractLab.countdownSteps(4) == 4;
        assertions++;

        System.out.println("assertions=" + assertions + " passed");
    }
}
