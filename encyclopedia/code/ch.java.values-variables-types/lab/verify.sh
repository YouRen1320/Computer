#!/usr/bin/env bash
set -eu

LAB_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TARGET_DIR=${1:-"$LAB_DIR/starter"}
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/factorycare-values-types.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

JAVAC_VERSION=$(javac -version 2>&1)
JAVA_VERSION=$(java -version 2>&1 | sed -n '1p')
MAVEN_VERSION=$(mvn -v 2>&1)
case "$JAVAC_VERSION" in
    "javac 25"|"javac 25."*) ;;
    *)
        echo "EXPECTED javac 25.x, got: $JAVAC_VERSION" >&2
        exit 2
        ;;
esac
case "$JAVA_VERSION" in
    *'version "25.'*|*'version "25"'*) ;;
    *)
        echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2
        exit 2
        ;;
esac
case "$MAVEN_VERSION" in
    *"Java version: 25."*|*"Java version: 25,"*) ;;
    *)
        echo "EXPECTED Maven runtime JDK 25.x, got:" >&2
        printf '%s\n' "$MAVEN_VERSION" >&2
        exit 2
        ;;
esac

if [ ! -f "$TARGET_DIR/pom.xml" ]; then
    echo "缺少 Maven 项目：$TARGET_DIR/pom.xml" >&2
    exit 1
fi

mvn -q -f "$TARGET_DIR/pom.xml" clean package
java -cp "$TARGET_DIR/target/classes" \
    com.factorycare.learning.DeviceStatusCard > "$TMP_DIR/actual-output.txt"

STARTER_COMPLETE=0
if diff -u "$LAB_DIR/expected-output.txt" "$TMP_DIR/actual-output.txt"; then
    STARTER_COMPLETE=1
    echo "PASS: learner implementation output matches expected-output.txt"
else
    echo "STARTER_INCOMPLETE: public starter compiles but its output is incomplete; complete the lab before claiming the build outcome"
fi

for source in "$LAB_DIR"/diagnostics/*.java; do
    name=$(basename "$source")
    log="$TMP_DIR/$name.log"
    output_dir="$TMP_DIR/classes-${name%.java}"
    mkdir -p "$output_dir"

    if javac -J-Duser.language=en -J-Duser.country=US \
        --release 25 -d "$output_dir" "$source" >"$log" 2>&1; then
        echo "FAIL: $name 本应编译失败，但 javac 返回了 0" >&2
        exit 1
    fi

    if ! grep -F "$name" "$log" >/dev/null; then
        echo "FAIL: $name 的错误日志没有可定位的文件名" >&2
        sed -n '1,40p' "$log" >&2
        exit 1
    fi

    case "$name" in
        OutOfScope.java)
            expected="cannot find symbol"
            ;;
        OverlappingLocalName.java)
            expected="variable openTicketCount is already defined"
            ;;
        UninitializedLocal.java)
            expected="variable openTicketCount might not have been initialized"
            ;;
        WrongTypeAssignment.java)
            expected="incompatible types: String cannot be converted to int"
            ;;
        *)
            echo "FAIL: 未登记诊断预言机：$name" >&2
            exit 1
            ;;
    esac

    if ! grep -F "$expected" "$log" >/dev/null; then
        echo "FAIL: $name 没有出现预期错误类别：$expected" >&2
        sed -n '1,40p' "$log" >&2
        exit 1
    fi

    echo "PASS: $name 按预期编译失败，证据=$expected"
done

BEHAVIOR_CLASSES="$TMP_DIR/behavior-classes"
mkdir -p "$BEHAVIOR_CLASSES"
javac --release 25 -d "$BEHAVIOR_CLASSES" "$LAB_DIR"/behavior-failures/*.java

java -cp "$BEHAVIOR_CLASSES" DiscardedNormalization >"$TMP_DIR/discarded-normalization.out"
printf '%s\n' '[  pump-a  ]' >"$TMP_DIR/discarded-normalization.expected"
diff -u "$TMP_DIR/discarded-normalization.expected" "$TMP_DIR/discarded-normalization.out"
echo "PASS: DiscardedNormalization reproduces a successful run with an unchanged String"

java -cp "$BEHAVIOR_CLASSES" RegexSplitBoundary >"$TMP_DIR/regex-split.out"
printf '%s\n' 'dotParts=0' 'csvParts=1' >"$TMP_DIR/regex-split.expected"
diff -u "$TMP_DIR/regex-split.expected" "$TMP_DIR/regex-split.out"
echo "PASS: RegexSplitBoundary reproduces regex-dot and trailing-empty loss"

echo "LAB HARNESS PASS: compile diagnostics and String behavior failures are reproducible javac=$JAVAC_VERSION java=$JAVA_VERSION"
if [ "$STARTER_COMPLETE" -eq 0 ]; then
    echo "UNVERIFIED: public starter output remains incomplete; only the lab harness and compile-error diagnostics passed"
    exit 0
fi

echo "PASS: learner implementation and diagnostic harness both satisfy the lab contract"
