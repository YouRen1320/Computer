import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

public final class FunctionalPipelinesOracle {
    private static int assertions;

    private FunctionalPipelinesOracle() {
    }

    private static void check(boolean condition, String name) {
        assertions++;
        if (!condition) {
            throw new AssertionError(name);
        }
    }

    private static void equal(Object expected, Object actual, String name) {
        check(Objects.equals(expected, actual), name + " expected=" + expected + " actual=" + actual);
    }

    private static String groups(Map<String, Integer> values) {
        List<String> parts = new ArrayList<>();
        values.forEach((key, value) -> parts.add(key + ":" + value));
        return String.join(",", parts);
    }

    public static void main(String[] args) {
        List<FunctionalPipelinesLab.WorkOrder> empty = List.of();
        FunctionalPipelinesLab.Summary emptyLoop = FunctionalPipelinesLab.summarizeWithLoop(empty);
        FunctionalPipelinesLab.Summary emptyStream = FunctionalPipelinesLab.summarizeWithStream(empty);
        equal(emptyLoop, emptyStream, "empty oracle equivalence");
        check(emptyStream.openIds().isEmpty(), "empty IDs");
        check(emptyStream.minutesByCategory().isEmpty(), "empty groups");
        equal(0, emptyStream.totalMinutes(), "empty total");
        check(emptyStream.maximumPriority().isEmpty(), "empty maximum");

        List<FunctionalPipelinesLab.WorkOrder> single = List.of(
                new FunctionalPipelinesLab.WorkOrder("WO-201", "MECHANICAL", 4, 15, true));
        FunctionalPipelinesLab.Summary singleLoop = FunctionalPipelinesLab.summarizeWithLoop(single);
        FunctionalPipelinesLab.Summary singleStream = FunctionalPipelinesLab.summarizeWithStream(single);
        equal(singleLoop, singleStream, "single oracle equivalence");
        equal(List.of("WO-201"), singleStream.openIds(), "single ID");
        equal(Map.of("MECHANICAL", 15), singleStream.minutesByCategory(), "single group");
        equal(15, singleStream.totalMinutes(), "single total");
        equal(4, singleStream.maximumPriority().orElseThrow(), "single maximum");

        List<FunctionalPipelinesLab.WorkOrder> multi = List.of(
                new FunctionalPipelinesLab.WorkOrder("WO-101", "MECHANICAL", 4, 30, true),
                new FunctionalPipelinesLab.WorkOrder("WO-102", "ELECTRICAL", 2, 45, false),
                new FunctionalPipelinesLab.WorkOrder("WO-103", "ELECTRICAL", 5, 20, true),
                new FunctionalPipelinesLab.WorkOrder("WO-104", "MECHANICAL", 3, 25, true),
                new FunctionalPipelinesLab.WorkOrder("WO-105", "NETWORK", 3, 40, true));
        FunctionalPipelinesLab.Summary multiLoop = FunctionalPipelinesLab.summarizeWithLoop(multi);
        FunctionalPipelinesLab.Summary multiStream = FunctionalPipelinesLab.summarizeWithStream(multi);
        equal(multiLoop, multiStream, "multi oracle equivalence");
        equal(List.of("WO-101", "WO-103", "WO-104", "WO-105"), multiStream.openIds(), "multi IDs");
        Map<String, Integer> expectedGroups = new LinkedHashMap<>();
        expectedGroups.put("MECHANICAL", 55);
        expectedGroups.put("ELECTRICAL", 20);
        expectedGroups.put("NETWORK", 40);
        equal(expectedGroups, multiStream.minutesByCategory(), "multi groups");
        equal(List.of("MECHANICAL", "ELECTRICAL", "NETWORK"),
                List.copyOf(multiStream.minutesByCategory().keySet()), "group order");
        equal(115, multiStream.totalMinutes(), "multi total");
        equal(5, multiStream.maximumPriority().orElseThrow(), "multi maximum");
        equal(5, multi.size(), "source unchanged");

        AtomicInteger fallbackCalls = new AtomicInteger();
        String present = FunctionalPipelinesLab.valueOrFallback(Optional.of("P5"), () -> {
            fallbackCalls.incrementAndGet();
            return "fallback";
        });
        equal("P5", present, "present value");
        equal(0, fallbackCalls.get(), "present is lazy");
        String missing = FunctionalPipelinesLab.valueOrFallback(Optional.empty(), () -> {
            fallbackCalls.incrementAndGet();
            return "fallback";
        });
        equal("fallback", missing, "empty fallback");
        equal(1, fallbackCalls.get(), "empty calls once");
        check(FunctionalPipelinesLab.highestPriority(empty).isEmpty(), "missing highest");

        System.out.println("report.empty=ids:0,groups:0,total:0,max:empty");
        System.out.println("report.single=ids:WO-201,groups:MECHANICAL:15,total:15,max:4");
        System.out.println("report.multi=ids:" + String.join(",", multiStream.openIds()));
        System.out.println("report.groups=" + groups(multiStream.minutesByCategory()));
        System.out.println("report.optional=present:" + present + ",empty:" + missing + ",calls:" + fallbackCalls.get());
        System.out.println("assertions=" + assertions + " passed");
    }
}
