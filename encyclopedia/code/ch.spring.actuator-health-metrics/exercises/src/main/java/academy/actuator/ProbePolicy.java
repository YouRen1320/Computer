package academy.actuator;

/** Exercise starter incorrectly restarts a healthy process when its database is unavailable. */
public final class ProbePolicy {
    private ProbePolicy() {}
    public record Signals(boolean live, boolean ready) {}
    public static Signals evaluate(boolean processHealthy, boolean databaseUp) { boolean all=processHealthy&&databaseUp; return new Signals(all,all); }
}
