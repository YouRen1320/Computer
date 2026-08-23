package com.factorycare.device.domain;

final class DeviceCodePolicy {
    private DeviceCodePolicy() {
    }

    static String normalize(String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            throw new IllegalArgumentException("code must not be blank");
        }
        return raw.trim().toUpperCase();
    }
}
