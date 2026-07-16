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
mkdir -p build/classes build/failures

javac --release 25 -encoding UTF-8 -Xlint:all -d build/classes src/AnnotationMetadataDemo.java
java -cp build/classes AnnotationMetadataDemo > build/demo.out
cmp expected.out build/demo.out

javap -v -classpath build/classes 'AnnotationMetadataDemo$DevicePolicy' > build/device-policy.javap
grep -q 'RuntimeVisibleAnnotations' build/device-policy.javap
grep -q 'RuntimeInvisibleAnnotations' build/device-policy.javap
grep -q 'ClassNote' build/device-policy.javap
grep -q 'RuntimeNote' build/device-policy.javap
if grep -q 'SourceNote' build/device-policy.javap; then
    echo 'SOURCE annotation unexpectedly survived in the class file' >&2
    exit 20
fi

if javac -J-Duser.language=en -J-Duser.country=US --release 25 -encoding UTF-8 -d build/failures failures/InvalidTargetFailure.java > build/target.out 2> build/target.err; then
    echo 'invalid target unexpectedly compiled' >&2
    exit 21
fi
grep -Eq 'not applicable|annotation type not applicable' build/target.err

if javac -J-Duser.language=en -J-Duser.country=US --release 25 -encoding UTF-8 -d build/failures failures/IllegalElementTypeFailure.java > build/element.out 2> build/element.err; then
    echo 'illegal annotation element type unexpectedly compiled' >&2
    exit 22
fi
grep -Eq 'invalid type for annotation interface element|invalid type for annotation type element' build/element.err

cat build/demo.out
