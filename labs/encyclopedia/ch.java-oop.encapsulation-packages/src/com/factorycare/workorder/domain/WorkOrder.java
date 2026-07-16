package com.factorycare.workorder.domain;

public final class WorkOrder {
    private final String id;
    private String status;
    private String assigneeId;

    public WorkOrder(String id) {
        this.id = requireText(id, "id");
        this.status = "CREATED";
    }

    public String id() {
        return id;
    }

    public String status() {
        return status;
    }

    public String assigneeId() {
        return assigneeId;
    }

    public void assign(String assigneeId) {
        StatusPolicy.requireCurrent(status, "CREATED");
        this.assigneeId = requireText(assigneeId, "assigneeId");
        this.status = "ASSIGNED";
    }

    public void start() {
        StatusPolicy.requireCurrent(status, "ASSIGNED");
        this.status = "IN_PROGRESS";
    }

    private static String requireText(String value, String field) {
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException(field + " must not be blank");
        }
        return value.trim();
    }
}
