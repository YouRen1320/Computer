import java.util.Locale;

public class DiscardedNormalization {
    public static void main(String[] args) {
        String code = "  pump-a  ";
        code.strip();
        code.toUpperCase(Locale.ROOT);

        // 故障 oracle：能运行，但原变量仍保留空格和小写。
        System.out.println("[" + code + "]");
    }
}
