package com.factorycare.learning;

import java.util.Arrays;

public class PriorityBatchCli {
    public static void main(String[] args) {
        if (args.length == 0) {
            System.err.println("USAGE: <priority> [<priority> ...]");
            System.exit(64);
        }

        try {
            int[] priorities = parsePriorities(args);
            printSummary(priorities);
        } catch (NumberFormatException ignored) {
            System.err.println("ERROR: priorities must be integers");
            System.exit(65);
        } catch (IllegalArgumentException exception) {
            System.err.println("ERROR: " + exception.getMessage());
            System.exit(66);
        }
    }

    private static int[] parsePriorities(String[] args) {
        int[] priorities = new int[args.length];

        for (int i = 0; i < args.length; i++) {
            priorities[i] = Integer.parseInt(args[i]);
        }

        return priorities;
    }

    private static void printSummary(int[] priorities) {
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
        System.out.println(
                "distribution="
                        + Arrays.toString(distribution)
        );
    }
}
