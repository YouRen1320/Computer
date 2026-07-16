package academy.actuator;

/** Reference policy keeps restart decisions independent from an external database outage. */
public final class ProbePolicy {
    private ProbePolicy() {}
    public record Signals(boolean live, boolean ready) {}
    public static Signals evaluate(boolean processHealthy, boolean databaseUp) { return new Signals(processHealthy,processHealthy&&databaseUp); }
}
