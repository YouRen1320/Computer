import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;

public final class FrameLengthFailure {
    private static final int MAX_FRAME_BYTES = 1_024;

    private FrameLengthFailure() {
    }

    public static void main(String[] args) throws Exception {
        byte[] header;
        try (ByteArrayOutputStream bytes = new ByteArrayOutputStream();
             DataOutputStream output = new DataOutputStream(bytes)) {
            output.writeInt(MAX_FRAME_BYTES + 1);
            header = bytes.toByteArray();
        }

        int status = 1;
        String evidence = "UNEXPECTED oversized frame reached allocation";
        boolean allocationAttempted = false;
        try (DataInputStream input = new DataInputStream(new ByteArrayInputStream(header))) {
            int declared = input.readInt();
            if (declared > MAX_FRAME_BYTES) {
                throw new FrameTooLargeException(declared, MAX_FRAME_BYTES);
            }
            byte[] payload = new byte[declared];
            allocationAttempted = payload.length == declared;
        } catch (FrameTooLargeException expected) {
            status = 8;
            evidence = "FRAME_LENGTH_REJECTED declared=1025 max=1024 allocationAttempted="
                    + allocationAttempted
                    + " cause="
                    + expected.getClass().getSimpleName();
        }

        System.err.println(evidence);
        System.exit(status);
    }

    private static final class FrameTooLargeException extends IOException {
        private FrameTooLargeException(int declared, int maximum) {
            super("declared=" + declared + ", maximum=" + maximum);
        }
    }
}
