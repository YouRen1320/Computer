import java.util.Scanner;

public class EofRetryOracle {
    public static void main(String[] args) {
        boolean retries = EofRetryBug.wouldRetryAfterRead(new Scanner(""));
        if (!retries) {
            throw new AssertionError("fixture changed: expected injected EOF retry bug");
        }
        System.out.println("EXPECTED_LOGIC_FAILURE eof-retry=true contract=must-terminate");
    }
}
