package com.factorycare.learning;

import java.util.Locale;

public class DeviceStatusCard {
    public static void main(String[] args) {
        long deviceId = 100000025L;
        String deviceName = "B区-冷却泵-02";
        int openTicketCount = 2;
        boolean enabled = true;
        String rawLabel = "  b区.冷却泵.02.  ";
        String blankText = " \t";
        String normalizedLabel = rawLabel.strip().toUpperCase(Locale.ROOT);
        String[] labelParts = normalizedLabel.split("\\.", -1);

        StringBuilder labelSummary = new StringBuilder();
        for (int index = 0; index < labelParts.length; index++) {
            if (index > 0) {
                labelSummary.append('|');
            }
            labelSummary.append(labelParts[index].isEmpty() ? "<empty>" : labelParts[index]);
        }

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

        System.out.println("空文本：" + rawLabel.isEmpty());
        System.out.println("空白文本：" + blankText.isBlank());
        System.out.println("正规化标签：" + normalizedLabel);
        System.out.println("标签段数：" + labelParts.length);
        System.out.println("标签汇总：" + labelSummary);
    }
}
