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

javac --release 25 -encoding UTF-8 -Xlint:all -d build/classes \
    src/factorycare/challenge/Scope.java \
    src/factorycare/challenge/RequiresRole.java \
    src/factorycare/challenge/RequiresRoles.java \
    src/factorycare/challenge/ChallengeApp.java
java -cp build/classes factorycare.challenge.ChallengeApp > build/solution.out
cmp expected.out build/solution.out
cat build/solution.out
