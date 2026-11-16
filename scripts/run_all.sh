#!/usr/bin/env bash
# Run the complete regression and synthesis flow, preserving both results.
# Both stages run even if the first one fails; the script exits nonzero if
# either stage fails.

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || { echo "ERROR: cannot enter project root"; exit 1; }

echo "############################################################"
echo "# 1/2 Functional regression"
echo "############################################################"
./scripts/run_tests.sh
test_status=$?

echo ""
echo "############################################################"
echo "# 2/2 Synthesis and structural checks"
echo "############################################################"
./scripts/run_synthesis.sh
synth_status=$?

echo ""
echo "############################################################"
echo "# Overall result"
echo "############################################################"
if [ "$test_status" -eq 0 ]; then
    echo "Regression: PASS"
else
    echo "Regression: FAIL"
fi
if [ "$synth_status" -eq 0 ]; then
    echo "Synthesis:  PASS"
else
    echo "Synthesis:  FAIL"
fi

if [ "$test_status" -ne 0 ] || [ "$synth_status" -ne 0 ]; then
    exit 1
fi
echo "Overall: PASS"
exit 0
