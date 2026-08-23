package com.factorycare.learning;

public class PriorityBatchAnalyzer {
    public static int countUrgent(int[] priorities) {
        validatePriorities(priorities);

        int urgentCount = 0;
        for (int priority : priorities) {
            if (priority >= 4) {
                urgentCount++;
            }
        }
        return urgentCount;
    }

    public static int countCritical(int[] priorities) {
        validatePriorities(priorities);

        int criticalCount = 0;
        for (int priority : priorities) {
            if (priority == 5) {
                criticalCount++;
            }
        }
        return criticalCount;
    }

    public static int findHighest(int[] priorities) {
        validatePriorities(priorities);

        if (priorities.length == 0) {
            return 0;
        }

        int highest = priorities[0];
        for (int i = 1; i < priorities.length; i++) {
            if (priorities[i] > highest) {
                highest = priorities[i];
            }
        }
        return highest;
    }

    public static int findFirstCriticalIndex(int[] priorities) {
        validatePriorities(priorities);

        for (int i = 0; i < priorities.length; i++) {
            if (priorities[i] == 5) {
                return i;
            }
        }
        return -1;
    }

    public static int[] buildDistribution(int[] priorities) {
        validatePriorities(priorities);

        int[] distribution = new int[6];
        for (int priority : priorities) {
            distribution[priority]++;
        }
        return distribution;
    }

    private static void validatePriorities(int[] priorities) {
        if (priorities == null) {
            throw new IllegalArgumentException("priorities must not be null");
        }

        for (int priority : priorities) {
            if (priority < 1 || priority > 5) {
                throw new IllegalArgumentException(
                        "priority must be between 1 and 5"
                );
            }
        }
    }
}
