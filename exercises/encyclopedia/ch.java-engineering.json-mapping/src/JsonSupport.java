import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.Serial;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public final class JsonSupport {
    private JsonSupport() {
    }

static final class FlatJson {
    private static final int MAX_CHARS = 100_000;

    private FlatJson() {
    }

    sealed interface Value permits TextValue, NumberValue, NullValue {
    }

    record TextValue(String value) implements Value {
        TextValue {
            Objects.requireNonNull(value, "value");
        }
    }

    record NumberValue(String lexeme) implements Value {
        NumberValue {
            Objects.requireNonNull(lexeme, "lexeme");
        }
    }

    enum NullValue implements Value {
        INSTANCE
    }

    static final class JsonSyntaxException extends IllegalArgumentException {
        @Serial
        private static final long serialVersionUID = 1L;

        JsonSyntaxException(String message) {
            super(message);
        }
    }

    static Map<String, Value> parseObject(String input) {
        Objects.requireNonNull(input, "input");
        if (input.length() > MAX_CHARS) {
            throw new JsonSyntaxException("JSON_TOO_LARGE");
        }
        Cursor cursor = new Cursor(input);
        Map<String, Value> fields = new LinkedHashMap<>();
        cursor.whitespace();
        cursor.expect('{');
        cursor.whitespace();
        if (cursor.consume('}')) {
            cursor.end();
            return Map.of();
        }
        while (true) {
            cursor.whitespace();
            String name = cursor.string();
            cursor.whitespace();
            cursor.expect(':');
            cursor.whitespace();
            Value value = cursor.value();
            if (fields.putIfAbsent(name, value) != null) {
                throw cursor.error("DUPLICATE_FIELD:" + name);
            }
            cursor.whitespace();
            if (cursor.consume('}')) {
                break;
            }
            cursor.expect(',');
        }
        cursor.end();
        return Collections.unmodifiableMap(new LinkedHashMap<>(fields));
    }

    static String quote(String value) {
        Objects.requireNonNull(value, "value");
        StringBuilder result = new StringBuilder(value.length() + 2);
        result.append('"');
        for (int index = 0; index < value.length(); index++) {
            char current = value.charAt(index);
            switch (current) {
                case '"' -> result.append("\\\"");
                case '\\' -> result.append("\\\\");
                case '\b' -> result.append("\\b");
                case '\f' -> result.append("\\f");
                case '\n' -> result.append("\\n");
                case '\r' -> result.append("\\r");
                case '\t' -> result.append("\\t");
                default -> {
                    if (current < 0x20) {
                        result.append(String.format("\\u%04x", (int) current));
                    } else {
                        result.append(current);
                    }
                }
            }
        }
        return result.append('"').toString();
    }

    private static final class Cursor {
        private final String input;
        private int index;

        Cursor(String input) {
            this.input = input;
        }

        void whitespace() {
            while (index < input.length()) {
                char current = input.charAt(index);
                if (current != ' ' && current != '\n' && current != '\r' && current != '\t') {
                    return;
                }
                index++;
            }
        }

        void expect(char expected) {
            if (!consume(expected)) {
                throw error("EXPECTED:" + expected);
            }
        }

        boolean consume(char expected) {
            if (index < input.length() && input.charAt(index) == expected) {
                index++;
                return true;
            }
            return false;
        }

        Value value() {
            if (index >= input.length()) {
                throw error("UNEXPECTED_END");
            }
            char current = input.charAt(index);
            if (current == '"') {
                return new TextValue(string());
            }
            if (current == '-' || Character.isDigit(current)) {
                return new NumberValue(number());
            }
            if (input.startsWith("null", index)) {
                index += 4;
                return NullValue.INSTANCE;
            }
            throw error("UNSUPPORTED_VALUE");
        }

        String string() {
            expect('"');
            StringBuilder result = new StringBuilder();
            while (index < input.length()) {
                char current = input.charAt(index++);
                if (current == '"') {
                    return result.toString();
                }
                if (current < 0x20) {
                    throw error("CONTROL_IN_STRING");
                }
                if (current != '\\') {
                    result.append(current);
                    continue;
                }
                if (index >= input.length()) {
                    throw error("UNEXPECTED_END");
                }
                char escaped = input.charAt(index++);
                switch (escaped) {
                    case '"', '\\', '/' -> result.append(escaped);
                    case 'b' -> result.append('\b');
                    case 'f' -> result.append('\f');
                    case 'n' -> result.append('\n');
                    case 'r' -> result.append('\r');
                    case 't' -> result.append('\t');
                    case 'u' -> result.append(unicode());
                    default -> throw error("INVALID_ESCAPE");
                }
            }
            throw error("UNTERMINATED_STRING");
        }

        private char unicode() {
            if (index + 4 > input.length()) {
                throw error("INVALID_UNICODE_ESCAPE");
            }
            int value = 0;
            for (int count = 0; count < 4; count++) {
                int digit = Character.digit(input.charAt(index++), 16);
                if (digit < 0) {
                    throw error("INVALID_UNICODE_ESCAPE");
                }
                value = value * 16 + digit;
            }
            return (char) value;
        }

        private String number() {
            int start = index;
            consume('-');
            if (consume('0')) {
                if (index < input.length() && Character.isDigit(input.charAt(index))) {
                    throw error("LEADING_ZERO");
                }
            } else {
                digitsRequired();
            }
            if (consume('.')) {
                digitsRequired();
            }
            if (index < input.length() && (input.charAt(index) == 'e' || input.charAt(index) == 'E')) {
                index++;
                if (index < input.length() && (input.charAt(index) == '+' || input.charAt(index) == '-')) {
                    index++;
                }
                digitsRequired();
            }
            String token = input.substring(start, index);
            if (token.length() > 64) {
                throw error("NUMBER_TOO_LONG");
            }
            return token;
        }

        private void digitsRequired() {
            int start = index;
            while (index < input.length() && Character.isDigit(input.charAt(index))) {
                index++;
            }
            if (start == index) {
                throw error("DIGIT_REQUIRED");
            }
        }

        void end() {
            whitespace();
            if (index != input.length()) {
                throw error("TRAILING_DATA");
            }
        }

        JsonSyntaxException error(String code) {
            return new JsonSyntaxException(code + " at=" + index);
        }
    }
}

static final class WorkOrderJsonMapper {
    private static final Set<String> KNOWN_FIELDS = Set.of(
            "schemaVersion", "id", "status", "openedAt", "amount", "assignee");

    private WorkOrderJsonMapper() {
    }

    enum UnknownFieldPolicy {
        REJECT,
        IGNORE
    }

    enum Status {
        OPEN,
        IN_PROGRESS,
        CLOSED
    }

    enum Presence {
        MISSING,
        EXPLICIT_NULL,
        VALUE
    }

    record OptionalText(Presence presence, String value) {
        OptionalText {
            Objects.requireNonNull(presence, "presence");
            if ((presence == Presence.VALUE) != (value != null)) {
                throw new IllegalArgumentException("value must exist only for VALUE");
            }
        }

        static OptionalText missing() {
            return new OptionalText(Presence.MISSING, null);
        }

        static OptionalText explicitNull() {
            return new OptionalText(Presence.EXPLICIT_NULL, null);
        }

        static OptionalText of(String value) {
            return new OptionalText(Presence.VALUE, Objects.requireNonNull(value, "value"));
        }
    }

    record WorkOrder(int schemaVersion, String id, Status status, Instant openedAt,
            BigDecimal amount, OptionalText assignee) {
        WorkOrder {
            if (schemaVersion != 1) {
                throw new MappingException("UNSUPPORTED_VERSION:schemaVersion");
            }
            Objects.requireNonNull(id, "id");
            if (id.isBlank()) {
                throw new MappingException("INVALID_TEXT:id");
            }
            Objects.requireNonNull(status, "status");
            Objects.requireNonNull(openedAt, "openedAt");
            Objects.requireNonNull(amount, "amount");
            Objects.requireNonNull(assignee, "assignee");
            if (amount.signum() < 0 || amount.scale() < 0 || amount.scale() > 2) {
                throw new MappingException("INVALID_AMOUNT:amount");
            }
        }
    }

    static final class MappingException extends IllegalArgumentException {
        @Serial
        private static final long serialVersionUID = 1L;

        MappingException(String message) {
            super(message);
        }

        MappingException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    static WorkOrder fromJson(String json, UnknownFieldPolicy policy) {
        Objects.requireNonNull(json, "json");
        Objects.requireNonNull(policy, "policy");
        // TODO 1..4: parse fields, enforce unknown policy, convert scalar types, and preserve assignee tri-state.
        return new WorkOrder(1, "TODO", Status.OPEN, Instant.EPOCH,
                BigDecimal.ZERO, OptionalText.missing());
    }

    static String toJson(WorkOrder order) {
        Objects.requireNonNull(order, "order");
        // TODO 5: serialize the canonical whitelist and preserve missing/null/value.
        return "{}";
    }

    private static String requireText(Map<String, FlatJson.Value> fields, String name) {
        FlatJson.Value value = require(fields, name);
        if (value == FlatJson.NullValue.INSTANCE) {
            throw new MappingException("NULL_REQUIRED:" + name);
        }
        if (value instanceof FlatJson.TextValue text) {
            return text.value();
        }
        throw new MappingException("TYPE_MISMATCH:" + name + " expected=string");
    }

    private static String requireNumber(Map<String, FlatJson.Value> fields, String name) {
        FlatJson.Value value = require(fields, name);
        if (value == FlatJson.NullValue.INSTANCE) {
            throw new MappingException("NULL_REQUIRED:" + name);
        }
        if (value instanceof FlatJson.NumberValue number) {
            return number.lexeme();
        }
        throw new MappingException("TYPE_MISMATCH:" + name + " expected=number");
    }

    private static FlatJson.Value require(Map<String, FlatJson.Value> fields, String name) {
        if (!fields.containsKey(name)) {
            throw new MappingException("MISSING_FIELD:" + name);
        }
        return fields.get(name);
    }

    private static int parseInteger(String token, String name) {
        try {
            return Integer.parseInt(token);
        } catch (NumberFormatException invalid) {
            throw new MappingException("INVALID_INTEGER:" + name, invalid);
        }
    }

    private static BigDecimal parseAmount(String token) {
        try {
            return new BigDecimal(token);
        } catch (NumberFormatException invalid) {
            throw new MappingException("INVALID_AMOUNT:amount", invalid);
        }
    }

    private static OptionalText parseOptionalText(Map<String, FlatJson.Value> fields, String name) {
        if (!fields.containsKey(name)) {
            return OptionalText.missing();
        }
        FlatJson.Value value = fields.get(name);
        if (value == FlatJson.NullValue.INSTANCE) {
            return OptionalText.explicitNull();
        }
        if (value instanceof FlatJson.TextValue text) {
            return OptionalText.of(text.value());
        }
        throw new MappingException("TYPE_MISMATCH:" + name + " expected=string|null");
    }
}

static final class JsonFiles {
    private static final int MAX_CHARS = 100_000;

    private JsonFiles() {
    }

    static void writeUtf8(Path path, String content) throws IOException {
        Objects.requireNonNull(path, "path");
        Objects.requireNonNull(content, "content");
        try (BufferedWriter writer = Files.newBufferedWriter(path, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING,
                StandardOpenOption.WRITE)) {
            writer.write(content);
        }
    }

    static String readUtf8(Path path) throws IOException {
        Objects.requireNonNull(path, "path");
        try (BufferedReader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
            StringBuilder result = new StringBuilder();
            char[] buffer = new char[1024];
            int count;
            while ((count = reader.read(buffer)) >= 0) {
                result.append(buffer, 0, count);
                if (result.length() > MAX_CHARS) {
                    throw new IOException("JSON_FILE_TOO_LARGE path=" + path);
                }
            }
            return result.toString();
        }
    }
}
}
