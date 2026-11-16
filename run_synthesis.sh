#!/usr/bin/env bash
# Synthesize both designs with Yosys and run structural checks.
# Two comparable flows are used:
#   1. RTL statistics after proc/opt/check (memories still visible)
#   2. Generic gate mapping after memory/techmap (generic cells, no timing)

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || { echo "ERROR: cannot enter project root"; exit 1; }

if ! command -v yosys >/dev/null 2>&1; then
    echo "ERROR: yosys is not installed or not on PATH."
    exit 1
fi

mkdir -p results/synthesis

RTL_FILES="rtl/address_decoder.v rtl/program_counter.v rtl/instruction_memory.v rtl/instruction_fetch.v rtl/data_memory.v rtl/memory_controller.v rtl/harvard_memory_system.v rtl/shared_port_memory.v rtl/harvard_demo.v"

echo "=== Yosys synthesis ==="
yosys -V | tee results/synthesis/tool_version.txt
echo ""

failed=0
declare -a failed_steps

run_yosys() {
    step_name="$1"
    top_name="$2"
    flow="$3"
    log_file="results/synthesis/${step_name}.log"

    if [ "$flow" = "rtl" ]; then
        script="read_verilog ${RTL_FILES}; hierarchy -top ${top_name}; proc; opt; check -assert; stat"
    else
        script="read_verilog ${RTL_FILES}; hierarchy -top ${top_name}; proc; opt; memory; opt; techmap; opt; check -assert; stat"
    fi

    if [ "$top_name" = "shared_port_memory" ] && [ "$flow" = "rtl" ]; then
        script="$script; select -assert-count 1 t:\$memrd"
    fi

    if yosys -p "$script" -l "$log_file" > /dev/null 2>&1; then
        if grep -q "Found and reported 0 problems." "$log_file"; then
            echo "PASS $step_name (structural check clean)"
        else
            echo "FAIL $step_name (structural check did not report zero problems)"
            failed=1
            failed_steps+=("$step_name")
        fi
    else
        echo "FAIL $step_name (yosys returned an error)"
        tail -30 "$log_file" 2>/dev/null | sed 's/^/    /'
        failed=1
        failed_steps+=("$step_name")
    fi
}

run_yosys "harvard_rtl"     "harvard_memory_system" "rtl"
run_yosys "harvard_generic" "harvard_memory_system" "generic"
run_yosys "shared_rtl"      "shared_port_memory"    "rtl"
run_yosys "shared_generic"  "shared_port_memory"    "generic"

run_yosys "demo_rtl"       "harvard_demo" "rtl"
run_yosys "demo_generic"   "harvard_demo" "generic"

# Concise statistics summary extracted from the final stat block of each log.
extract_last_stat() {
    log_file="$1"
    top_name="$2"
    awk -v pattern="=== ${top_name} ===" '
        $0 ~ pattern { block = ""; capture = 1 }
        capture { sub(/[ \t]+$/, ""); block = block $0 "\n" }
        END { printf "%s", block }
    ' "$log_file"
}

{
    echo "Memory Hierarchy - Yosys synthesis summary"
    echo "$(yosys -V)"
    echo ""
    echo "Flow 1 (RTL):     read_verilog; hierarchy; proc; opt; check -assert; stat"
    echo "Flow 2 (generic): read_verilog; hierarchy; proc; opt; memory; opt; techmap; opt; check -assert; stat"
    echo ""
    echo "===== Harvard - RTL statistics ====="
    extract_last_stat "results/synthesis/harvard_rtl.log" "harvard_memory_system"
    echo ""
    echo "===== Harvard - generic cell statistics ====="
    extract_last_stat "results/synthesis/harvard_generic.log" "harvard_memory_system"
    echo ""
    echo "===== Shared - RTL statistics ====="
    extract_last_stat "results/synthesis/shared_rtl.log" "shared_port_memory"
    echo ""
    echo "===== Shared - generic cell statistics ====="
    extract_last_stat "results/synthesis/shared_generic.log" "shared_port_memory"
    echo ""
    echo "===== Demo controller - RTL statistics ====="
    extract_last_stat "results/synthesis/demo_rtl.log" "harvard_demo"
    echo ""
    echo "===== Demo controller - generic statistics ====="
    extract_last_stat "results/synthesis/demo_generic.log" "harvard_demo"
} > results/synthesis/summary.txt

echo ""
echo "Synthesis logs and summary saved in results/synthesis/"
if [ "$failed" -ne 0 ]; then
    echo "Synthesis summary: FAILED steps: ${failed_steps[*]}"
    exit 1
fi
python3 scripts/synthesis_report.py || exit 1
echo "Synthesis summary: all six runs passed with zero structural problems"
exit 0
