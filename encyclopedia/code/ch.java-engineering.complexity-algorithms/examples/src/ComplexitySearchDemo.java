import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class ComplexitySearchDemo {
    private ComplexitySearchDemo() {
    }

    public static void main(String[] args) {
        List<String> ids = ids(128);
        SearchResult linearMissing = linearSearch(ids, "WO-999");
        SearchResult binaryMissing = binarySearch(ids, "WO-999");
        SearchResult linearFound = linearSearch(ids, "WO-073");
        SearchResult binaryFound = binarySearch(ids, "WO-073");

        System.out.println("linear.missing.comparisons=" + linearMissing.comparisons());
        System.out.println("binary.missing.comparisons=" + binaryMissing.comparisons());
        System.out.println("linear.found.index=" + linearFound.index()
                + ",comparisons=" + linearFound.comparisons());
        System.out.println("binary.found.index=" + binaryFound.index()
                + ",comparisons=" + binaryFound.comparisons());
        for (int size : List.of(100, 10_000, 1_000_000)) {
            System.out.println("model.n=" + size + ",linear=" + size
                    + ",binaryCeiling=" + ceilLog2(size));
        }
        System.out.println("nested.unique.n=16,pairs=" + pairCount(16));

        Map<String, String> index = new HashMap<>();
        for (String id : ids) {
            index.put(id, id);
        }
        System.out.println("map.index.size=" + index.size());
        System.out.println("map.lookup=" + index.get("WO-073"));
    }

    static SearchResult linearSearch(List<String> values, String target) {
        long comparisons = 0;
        for (int index = 0; index < values.size(); index++) {
            comparisons++;
            if (values.get(index).equals(target)) {
                return new SearchResult(index, comparisons);
            }
        }
        return new SearchResult(-1, comparisons);
    }

    static SearchResult binarySearch(List<String> values, String target) {
        int low = 0;
        int high = values.size() - 1;
        long comparisons = 0;
        while (low <= high) {
            int middle = low + (high - low) / 2;
            comparisons++;
            int relation = values.get(middle).compareTo(target);
            if (relation < 0) {
                low = middle + 1;
            } else if (relation > 0) {
                high = middle - 1;
            } else {
                return new SearchResult(middle, comparisons);
            }
        }
        return new SearchResult(-1, comparisons);
    }

    static int ceilLog2(int value) {
        int power = 0;
        int current = 1;
        while (current < value) {
            current *= 2;
            power++;
        }
        return power;
    }

    static long pairCount(long size) {
        return size * (size - 1) / 2;
    }

    private static List<String> ids(int size) {
        List<String> result = new ArrayList<>(size);
        for (int index = 0; index < size; index++) {
            result.add(String.format(Locale.ROOT, "WO-%03d", index));
        }
        return List.copyOf(result);
    }

    record SearchResult(int index, long comparisons) {
    }
}
