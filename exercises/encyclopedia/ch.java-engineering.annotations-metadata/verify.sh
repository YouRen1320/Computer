#!/bin/sh
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
mkdir -p build/classes

set +e
javac -J-Duser.language=en -J-Duser.country=US --release 25 -encoding UTF-8 -Xlint:all -d build/classes \
    src/factorycare/challenge/Scope.java \
    src/factorycare/challenge/RequiresRole.java \
    src/factorycare/challenge/RequiresRoles.java \
    src/factorycare/challenge/ChallengeApp.java \
    > build/compile.out 2> build/compile.err
compile_status=$?
set -e

if [ "$compile_status" -ne 0 ]; then
    grep -Eq 'not repeatable|duplicate annotation|not applicable|containing annotation' build/compile.err
    echo "STARTER EXPECTED FAILURE status=compile-$compile_status; complete TODO 1..4"
    exit 0
fi

set +e
java -cp build/classes factorycare.challenge.ChallengeApp > build/challenge.out 2> build/challenge.err
run_status=$?
set -e

if [ "$run_status" -ne 0 ]; then
    grep -q 'METADATA_CONTRACT' build/challenge.err
    echo "STARTER EXPECTED FAILURE status=runtime-$run_status; finish retention/inheritance contract"
    exit 0
fi

cmp expected.out build/challenge.out
cat build/challenge.out
