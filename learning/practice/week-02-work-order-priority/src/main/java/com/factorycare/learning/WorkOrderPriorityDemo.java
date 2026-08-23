package com.factorycare.learning;

import java.util.Arrays;

public class WorkOrderPriorityDemo {
    public static void main(String[] args) {
        printPriority("GENERAL", 3, false, 2);
        printPriority("PRODUCTION", 30, false, 2);
        printPriority("SAFETY", 1, false, 30);
        printPriority("GENERAL", 1, true, 2);

        printBatchSummary(new int[]{2, 4, 5, 3, 4});
    }

    private static void printPriority(
            String category,
            int affectedUsers,
            boolean machineStopped,
            int waitingHours
    ) {
        int priority = WorkOrderPriorityCalculator.calculatePriority(
                category,
                affectedUsers,
                machineStopped,
                waitingHours
        );

        System.out.println(
                "category=" + category
                        + " affectedUsers=" + affectedUsers
                        + " machineStopped=" + machineStopped
                        + " waitingHours=" + waitingHours
                        + " priority=" + priority
        );
    }

    private static void printBatchSummary(int[] priorities) {
        int urgentCount = PriorityBatchAnalyzer.countUrgent(priorities);
        int criticalCount = PriorityBatchAnalyzer.countCritical(priorities);
        int highest = PriorityBatchAnalyzer.findHighest(priorities);
        int firstCriticalIndex = PriorityBatchAnalyzer
                .findFirstCriticalIndex(priorities);
        int[] distribution = PriorityBatchAnalyzer
                .buildDistribution(priorities);

        System.out.println("batch=" + Arrays.toString(priorities));
        System.out.println("urgentCount=" + urgentCount);
        System.out.println("criticalCount=" + criticalCount);
        System.out.println("highest=" + highest);
        System.out.println("firstCriticalIndex=" + firstCriticalIndex);
        System.out.println("distribution=" + Arrays.toString(distribution));
    }
}
