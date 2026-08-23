package com.factorycare.learning;

import java.util.Locale;

public class StringFoundations {
    public static void main(String[] args) {
        String raw = "  pump-a.01.  ";
        String normalized = raw.strip().toUpperCase(Locale.ROOT);
        String[] fields = normalized.split("\\.", -1);
        String blank = " \t";

        StringBuilder summary = new StringBuilder();
        for (int index = 0; index < fields.length; index++) {
            if (index > 0) {
                summary.append('|');
            }
            summary.append(fields[index].isEmpty() ? "<empty>" : fields[index]);
        }

        System.out.println("rawLength=" + raw.length());
        System.out.println("normalized=" + normalized);
        System.out.println("empty=" + raw.isEmpty() + ", blank=" + blank.isBlank());
        System.out.println("parts=" + fields.length + ", tailEmpty=" + fields[2].isEmpty());
        System.out.println("summary=" + summary);
        System.out.println("rawUnchanged=[" + raw + "]");
    }
}
