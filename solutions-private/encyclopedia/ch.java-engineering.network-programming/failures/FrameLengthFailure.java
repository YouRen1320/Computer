import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.net.ProtocolException;

public final class FrameLengthFailure {
    private static final int MAX_FRAME_BYTES = 2_048;

    public static void main(String[] args) throws Exception {
        byte[] prefix = {0, 0, 16, 0};
        boolean rejected = false;
        try (DataInputStream input = new DataInputStream(new ByteArrayInputStream(prefix))) {
            int declared = input.readInt();
            if (declared < 0 || declared > MAX_FRAME_BYTES) {
                throw new ProtocolException("frame length=" + declared);
            }
        } catch (ProtocolException expected) {
            rejected = true;
        }
        if (!rejected) {
            throw new AssertionError("oversized frame was accepted");
        }
        System.err.println("FRAME_LENGTH_REJECTED declared=4096 max=2048 exception=ProtocolException");
        System.exit(8);
    }
}
