#!/usr/bin/env bash
set -euo pipefail
# Run real ObjectScript tests in a dedicated test container; does not connect to existing customer instances.
container=${IRIS_TEST_CONTAINER:-iris-fhir-openapi-test}
project_dir=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$project_dir/.local"
if ! openssl x509 -in "$project_dir/.local/tls-cert.pem" -checkend 60 -noout >/dev/null 2>&1; then
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$project_dir/.local/tls-key.pem" -out "$project_dir/.local/tls-cert.pem" -days 2 -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost' >/dev/null 2>&1
  chmod 600 "$project_dir/.local/tls-key.pem"
fi
docker exec "$container" pkill -f '^python3 /workspace/scripts/mock_metadata.py( --tls)?$' >/dev/null 2>&1 || true
docker exec -d "$container" python3 /workspace/scripts/mock_metadata.py
docker exec -d "$container" python3 /workspace/scripts/mock_metadata.py --tls
log=$(mktemp)
trap 'rm -f "$log"' EXIT
docker exec -i "$container" iris session IRIS -U USER <<'COS' | tee "$log"
set sc=$SYSTEM.OBJ.LoadDir("/workspace/src","ck",,1)
if $SYSTEM.Status.IsError(sc) { do $SYSTEM.Status.DisplayError(sc) halt }
set sc=$SYSTEM.OBJ.LoadDir("/workspace/tests","ck",,1)
if $SYSTEM.Status.IsError(sc) { do $SYSTEM.Status.DisplayError(sc) halt }
set ^UnitTestRoot="/workspace/tests"
set ok=##class(%UnitTest.Manager).RunTest("Test/FHIROpenAPI","/nodelete/noload")
if 'ok halt

halt
COS
if grep -Eq '(^ERROR|\*\*FAILED\*\*|<SYNTAX>|Some tests FAILED)' "$log"; then exit 1; fi
grep -q '^All PASSED' "$log"
