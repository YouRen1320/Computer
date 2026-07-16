package com.factorycare.learning;

public class DeviceStatusCard {
    public static void main(String[] args) {
        long deviceId = 100000025L;
        String deviceName = "B区-冷却泵-02";
        int openTicketCount = 2;
        boolean enabled = true;

        System.out.println("=== 设备状态卡 ===");
        System.out.print("设备ID：");
        System.out.println(deviceId);
        System.out.print("设备名称：");
        System.out.println(deviceName);
        System.out.print("未关闭工单：");
        System.out.println(openTicketCount);
        System.out.print("启用：");
        System.out.println(enabled);

        {
            String currentSection = "值班检查";
            System.out.print("当前区块：");
            System.out.println(currentSection);
        }
    }
}
