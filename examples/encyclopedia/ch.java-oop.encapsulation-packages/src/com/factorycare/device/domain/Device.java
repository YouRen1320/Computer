package com.factorycare.device.domain;

public final class Device {
    private final String code;
    private String status;

    public Device(String code) {
        this.code = DeviceCodePolicy.normalize(code);
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
