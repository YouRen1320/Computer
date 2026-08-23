public class RegexSplitBoundary {
    public static void main(String[] args) {
        String[] dotParts = "PUMP.01".split(".");
        String[] csvParts = "PUMP,".split(",");

        // 故障 oracle：`.` 是正则元字，默认 limit 又会丢弃尾部空片段。
        System.out.println("dotParts=" + dotParts.length);
        System.out.println("csvParts=" + csvParts.length);
    }
}
