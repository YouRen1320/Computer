package com.factorycare.device.domain;

public final class Device {
    private final String code;
    public String status; // TODO：改为 private，外部仍通过 status() 读取。

    public Device(String code) {
        if (code == null || code.trim().isEmpty()) {
            throw new IllegalArgumentException("code must not be blank");
        }
        this.code = code.trim().toUpperCase();
        this.status = "REGISTERED";
    }

    public String code() {
        return code;
    }

    public String status() {
        return status;
    }

    public void startRepair() {
        if (!"REGISTERED".equals(status)) {
            throw new IllegalStateException("repair already started");
        }
        status = "IN_REPAIR";
    }
}
