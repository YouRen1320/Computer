package com.factorycare.learning;

import java.util.Locale;

public class WorkOrderPriorityCalculator {
    public static int calculatePriority(
            String category,
            int affectedUsers,
            boolean machineStopped,
            int waitingHours
    ) {
        if (category == null || category.isBlank()) {
            throw new IllegalArgumentException("category is required");
        }

        if (affectedUsers < 0 || waitingHours < 0) {
            throw new IllegalArgumentException("numbers must not be negative");
        }

        String normalizedCategory = category
                .strip()
                .toUpperCase(Locale.ROOT);

        int priority = switch (normalizedCategory) {
            case "SAFETY" -> 4;
            case "PRODUCTION" -> 3;
            case "GENERAL" -> 2;
            default -> throw new IllegalArgumentException(
                    "unknown category: " + category
            );
        };

        if (machineStopped) {
            return 5;
        }

        if (affectedUsers >= 20) {
            priority = Math.max(priority, 4);
        }

        if (waitingHours >= 24) {
            priority = Math.max(priority, 3);
        }

        return priority;
    }
}
