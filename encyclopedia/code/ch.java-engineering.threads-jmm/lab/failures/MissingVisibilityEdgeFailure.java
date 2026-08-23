import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;

public final class MissingVisibilityEdgeFailure {
    private MissingVisibilityEdgeFailure() {
    }

    private static final class BrokenSignal {
        private boolean ready;

        boolean isReady() {
            return ready;
        }

        void stop() {
            ready = true;
        }
    }

    public static void main(String[] args) throws Exception {
        Field field = BrokenSignal.class.getDeclaredField("ready");
        Method read = BrokenSignal.class.getDeclaredMethod("isReady");
        Method write = BrokenSignal.class.getDeclaredMethod("stop");
        boolean hasEdge = Modifier.isVolatile(field.getModifiers())
                || (Modifier.isSynchronized(read.getModifiers())
                && Modifier.isSynchronized(write.getModifiers()));
        if (!hasEdge) {
            throw new IllegalStateException("MISSING_VISIBILITY_EDGE ready=plain");
        }
    }
}
