#!/usr/bin/env bash
set -eu

cd "$(dirname "$0")"
export LC_ALL=C

case "$(javac -version 2>&1)" in
    "javac 25"|"javac 25."*) ;;
    *) echo 'EXPECTED javac 25' >&2; exit 2 ;;
esac
case "$(java -version 2>&1)" in
    *'version "25.'*|*'version "25"'*) ;;
    *) echo 'EXPECTED java 25' >&2; exit 2 ;;
esac

rm -rf build
mkdir -p build/processor build/classes build/generated build/failures build/invalid-role

javac --release 25 -encoding UTF-8 -Xlint:all -d build/processor \
    src/factorycare/metadata/Scope.java \
    src/factorycare/metadata/RequiresRole.java \
    src/factorycare/metadata/RequiresRoles.java \
    src/factorycare/metadata/CompileReport.java \
    src/factorycare/metadata/ClassAudit.java \
    processor/factorycare/processor/RequiresRoleProcessor.java

javac --release 25 -encoding UTF-8 -Xlint:all \
    -cp build/processor \
    --processor-path build/processor \
    -processor factorycare.processor.RequiresRoleProcessor \
    -s build/generated \
    -d build/classes \
    src/factorycare/app/WorkOrderPolicy.java \
    src/factorycare/app/UrgentWorkOrderPolicy.java \
    src/factorycare/app/VerificationApp.java

test -f build/generated/factorycare/generated/RoleIndex.java
grep -q 'sourceSeen() { return true; }' build/generated/factorycare/generated/RoleIndex.java
grep -q 'WorkOrderPolicy#ADMIN@TENANT' build/generated/factorycare/generated/RoleIndex.java

java -cp build/classes:build/processor factorycare.app.VerificationApp > build/lab.out
cmp expected.out build/lab.out

javap -v -classpath build/classes:build/processor factorycare.app.WorkOrderPolicy > build/work-order-policy.javap
grep -q 'RuntimeVisibleAnnotations' build/work-order-policy.javap
grep -q 'RuntimeInvisibleAnnotations' build/work-order-policy.javap
grep -q 'ClassAudit' build/work-order-policy.javap
if grep -q 'CompileReport' build/work-order-policy.javap; then
    echo 'SOURCE CompileReport unexpectedly survived in the class file' >&2
    exit 20
fi

if javac -J-Duser.language=en -J-Duser.country=US --release 25 -encoding UTF-8 -d build/failures failures/invalid-target/InvalidTarget.java > build/target.out 2> build/target.err; then
    echo 'invalid target unexpectedly compiled' >&2
    exit 21
fi
grep -Eq 'not applicable|annotation type not applicable' build/target.err

if javac -J-Duser.language=en -J-Duser.country=US --release 25 -encoding UTF-8 \
    -cp build/processor \
    --processor-path build/processor \
    -processor factorycare.processor.RequiresRoleProcessor \
    -d build/invalid-role \
    failures/invalid-role/factorycare/failure/InvalidRole.java \
    > build/role.out 2> build/role.err; then
    echo 'invalid role unexpectedly passed processor validation' >&2
    exit 22
fi
grep -q 'role must match \[A-Z\]\[A-Z0-9_\]\*' build/role.err

javac --release 25 -encoding UTF-8 -d build/failures failures/source-retention/SourceRetentionFailure.java
set +e
java -cp build/failures SourceRetentionFailure > build/source.out 2> build/source.err
source_status=$?
set -e
test "$source_status" -eq 7
grep -q 'source-retention-present=false' build/source.out
grep -q 'first-evidence=runtime probe could not see SOURCE annotation' build/source.err

javac --release 25 -encoding UTF-8 -d build/failures failures/missing-retention/MissingRetentionFailure.java
set +e
java -cp build/failures MissingRetentionFailure > build/missing.out 2> build/missing.err
missing_status=$?
set -e
test "$missing_status" -eq 8
grep -q 'missing-retention-present=false' build/missing.out
grep -q 'first-evidence=omitted @Retention defaults to CLASS, not RUNTIME' build/missing.err

cat build/lab.out
