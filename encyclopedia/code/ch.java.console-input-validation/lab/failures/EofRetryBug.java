import java.util.Scanner;

public class EofRetryBug {
    static boolean wouldRetryAfterRead(Scanner scanner) {
        if (!scanner.hasNextLine()) {
            return true; // 故意错误：EOF 是终止状态，不是“暂时还没输入”。
        }
        scanner.nextLine();
        return false;
    }
}
