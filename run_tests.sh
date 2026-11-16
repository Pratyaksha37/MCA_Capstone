#!/usr/bin/env bash
# Compile and run every self-checking testbench.
# The regression fails on compile errors, simulation errors, failed PASS
# markers, missing/nonempty waveform files, or a missing performance report.

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || { echo "ERROR: cannot enter project root"; exit 1; }

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog is not installed or not on PATH."
    exit 1
fi
if ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: vvp is not installed or not on PATH."
    exit 1
fi

mkdir -p results/simulation results/waveforms results/performance
rm -f results/performance/performance_summary.txt
rm -f results/performance/performance_simulation.log

TESTBENCHES="tb_program_counter tb_instruction_memory tb_data_memory tb_harvard_memory_system tb_shared_port_memory tb_memory_comparison tb_harvard_demo tb_memory_edges"

total=0
passed=0
failed=0
failed_names=""

echo "=== Memory Hierarchy regression ==="
echo "Project root: $PROJECT_ROOT"
echo "iverilog: $(iverilog -V 2>&1 | head -1)"
echo ""

for tb in $TESTBENCHES; do
    total=$((total + 1))
    compile_log="results/simulation/${tb}.compile.log"
    run_log="results/simulation/${tb}.log"
    vvp_file="results/simulation/${tb}.vvp"
    vcd_file="results/waveforms/${tb}.vcd"
    test_ok=1

    rm -f "$vvp_file" "$run_log" "$vcd_file"

    if ! iverilog -g2005 -Wall -o "$vvp_file" rtl/*.v "tb/${tb}.v" > "$compile_log" 2>&1; then
        echo "FAIL (compile) $tb"
        sed 's/^/    /' "$compile_log"
        test_ok=0
    else
        if ! vvp "$vvp_file" > "$run_log" 2>&1; then
            echo "FAIL (simulation) $tb"
            tail -20 "$run_log" | sed 's/^/    /'
            test_ok=0
        elif ! grep -q ": PASS" "$run_log"; then
            echo "FAIL (no PASS marker) $tb"
            tail -20 "$run_log" | sed 's/^/    /'
            test_ok=0
        elif [ ! -s "$vcd_file" ]; then
            echo "FAIL (missing waveform) $tb"
            test_ok=0
        elif [ "$tb" = "tb_memory_comparison" ] && [ ! -s "results/performance/performance_summary.txt" ]; then
            echo "FAIL (missing performance summary) $tb"
            test_ok=0
        fi
    fi

    if [ "$test_ok" -eq 1 ]; then
        echo "PASS $tb"
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        failed_names="$failed_names $tb"
    fi
done

echo ""
echo "Regression summary: total=$total passed=$passed failed=$failed"
if [ "$failed" -ne 0 ]; then
    echo "Failed tests:$failed_names"
fi

{
    echo "Memory Hierarchy regression summary"
    echo "Total tests: $total"
    echo "Passed: $passed"
    echo "Failed: $failed"
    if [ "$failed" -ne 0 ]; then
        echo "Failed test names:$failed_names"
    fi
} > results/simulation/regression_summary.txt

# Preserve the performance-test output alongside its generated report.
if [ -f results/simulation/tb_memory_comparison.log ]; then
    cp results/simulation/tb_memory_comparison.log results/performance/performance_simulation.log
fi

if [ "$failed" -ne 0 ]; then
    exit 1
fi
python3 scripts/verify_waveforms.py || exit 1
exit 0
