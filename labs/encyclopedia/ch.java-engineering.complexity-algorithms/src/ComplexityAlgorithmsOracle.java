import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public final class ComplexityAlgorithmsOracle {
    private ComplexityAlgorithmsOracle() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<Integer> values1024 = range(1024);
        ComplexityAlgorithmsLab.SearchResult linearMissing =
                ComplexityAlgorithmsLab.linearSearch(values1024, -1);
        ComplexityAlgorithmsLab.SearchResult binaryMissing =
                ComplexityAlgorithmsLab.binarySearch(values1024, -1);
        check(linearMissing.index() == -1 && binaryMissing.index() == -1, "same missing result"); assertions++;
        check(linearMissing.comparisons() == 1024, "linear missing count"); assertions++;
        check(binaryMissing.comparisons() == 10, "binary missing count"); assertions++;
        check(binaryMissing.comparisons() < linearMissing.comparisons(), "binary growth"); assertions++;
        check(ComplexityAlgorithmsLab.linearSearch(values1024, 512).index()
                == ComplexityAlgorithmsLab.binarySearch(values1024, 512).index(), "same found index"); assertions++;

        check(ComplexityAlgorithmsLab.ceilLog2(128) == 7, "scale 128"); assertions++;
        check(ComplexityAlgorithmsLab.ceilLog2(1024) == 10, "scale 1024"); assertions++;
        check(ComplexityAlgorithmsLab.ceilLog2(8192) == 13, "scale 8192"); assertions++;
        check(ComplexityAlgorithmsLab.ceilLog2(1_000_000) == 20, "model million"); assertions++;

        List<Integer> uniqueInput = range(64);
        ComplexityAlgorithmsLab.DedupResult naive =
                ComplexityAlgorithmsLab.naiveDeduplicate(uniqueInput);
        ComplexityAlgorithmsLab.DedupResult indexed =
                ComplexityAlgorithmsLab.setDeduplicate(uniqueInput);
        check(naive.unique().equals(indexed.unique()), "dedup same result"); assertions++;
        check(naive.unique().size() == 64, "unique size"); assertions++;
        check(naive.operations() == 2016, "quadratic pair count"); assertions++;
        check(indexed.operations() == 64, "set operation count"); assertions++;
        check(naive.operations() > indexed.operations() * 20, "growth gap"); assertions++;

        List<Integer> unsorted = List.of(9, 1, 7, 3, 5);
        List<Integer> targets = List.of(1, 3, 8, 9);
        ComplexityAlgorithmsLab.QueryReport repeated =
                ComplexityAlgorithmsLab.sortForEveryQuery(unsorted, targets);
        ComplexityAlgorithmsLab.QueryReport reused =
                ComplexityAlgorithmsLab.reuseSortedSnapshot(unsorted, targets);
        check(repeated.positions().equals(reused.positions()), "query results equal"); assertions++;
        check(repeated.sortCalls() == 4, "repeated sort calls"); assertions++;
        check(reused.sortCalls() == 1, "reused sort calls"); assertions++;
        check(unsorted.equals(List.of(9, 1, 7, 3, 5)), "source unchanged"); assertions++;

        Map<Integer, String> index = new HashMap<>();
        for (Integer value : values1024) {
            index.put(value, "WO-" + value);
        }
        check(index.size() == 1024, "map index size"); assertions++;
        check("WO-512".equals(index.get(512)), "map lookup"); assertions++;

        System.out.println("report.search=n:1024,linearMissing:" + linearMissing.comparisons()
                + ",binaryMissing:" + binaryMissing.comparisons());
        System.out.println("report.scale=128:128/7,1024:1024/10,8192:8192/13");
        System.out.println("report.model=100:100/7,10000:10000/14,1000000:1000000/20");
        System.out.println("report.dedup=n:64,naivePairs:" + naive.operations()
                + ",setChecks:" + indexed.operations());
        System.out.println("report.repeatedSort=queries:4,repeated:" + repeated.sortCalls()
                + ",reused:" + reused.sortCalls());
        System.out.println("assertions=" + assertions + " passed");
    }

    private static List<Integer> range(int size) {
        List<Integer> result = new ArrayList<>(size);
        for (int value = 0; value < size; value++) {
            result.add(value);
        }
        return List.copyOf(result);
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
