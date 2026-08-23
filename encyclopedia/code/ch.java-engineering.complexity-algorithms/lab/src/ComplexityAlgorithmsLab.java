import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

final class ComplexityAlgorithmsLab {
    private ComplexityAlgorithmsLab() {
    }

    static SearchResult linearSearch(List<Integer> values, int target) {
        long comparisons = 0;
        for (int index = 0; index < values.size(); index++) {
            comparisons++;
            if (values.get(index) == target) {
                return new SearchResult(index, comparisons);
            }
        }
        return new SearchResult(-1, comparisons);
    }

    static SearchResult binarySearch(List<Integer> values, int target) {
        int low = 0;
        int high = values.size() - 1;
        long comparisons = 0;
        while (low <= high) {
            int middle = low + (high - low) / 2;
            comparisons++;
            int relation = Integer.compare(values.get(middle), target);
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

    static DedupResult naiveDeduplicate(List<Integer> input) {
        List<Integer> unique = new ArrayList<>();
        long comparisons = 0;
        for (Integer candidate : input) {
            boolean seen = false;
            for (Integer existing : unique) {
                comparisons++;
                if (existing.equals(candidate)) {
                    seen = true;
                    break;
                }
            }
            if (!seen) {
                unique.add(candidate);
            }
        }
        return new DedupResult(List.copyOf(unique), comparisons);
    }

    static DedupResult setDeduplicate(List<Integer> input) {
        Set<Integer> unique = new LinkedHashSet<>();
        long membershipChecks = 0;
        for (Integer candidate : input) {
            membershipChecks++;
            unique.add(candidate);
        }
        return new DedupResult(List.copyOf(unique), membershipChecks);
    }

    static QueryReport sortForEveryQuery(List<Integer> source, List<Integer> targets) {
        List<Integer> positions = new ArrayList<>();
        int sortCalls = 0;
        for (Integer target : targets) {
            List<Integer> sorted = new ArrayList<>(source);
            sorted.sort(Integer::compare);
            sortCalls++;
            positions.add(Collections.binarySearch(sorted, target));
        }
        return new QueryReport(List.copyOf(positions), sortCalls);
    }

    static QueryReport reuseSortedSnapshot(List<Integer> source, List<Integer> targets) {
        List<Integer> sorted = new ArrayList<>(source);
        sorted.sort(Integer::compare);
        List<Integer> positions = new ArrayList<>();
        for (Integer target : targets) {
            positions.add(Collections.binarySearch(sorted, target));
        }
        return new QueryReport(List.copyOf(positions), 1);
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

    record SearchResult(int index, long comparisons) {
    }

    record DedupResult(List<Integer> unique, long operations) {
    }

    record QueryReport(List<Integer> positions, int sortCalls) {
    }
}
