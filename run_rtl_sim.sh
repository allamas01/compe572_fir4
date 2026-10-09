#!/bin/bash
# =============================================================================
# run_rtl_sim.sh -- RTL simulation driver
#
# Usage:
#   bash scripts/run_rtl_sim.sh            # batch, checks log for TEST PASSED
#   GUI=1 bash scripts/run_rtl_sim.sh      # SimVision waveforms
#
# Log: output/rtl_sim.log
# =============================================================================
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL="${PROJECT_DIR}/rtl/fir4.sv"
TB="${PROJECT_DIR}/tb/tb_fir4.sv"
LOG="${PROJECT_DIR}/output/rtl_sim.log"
GUI=${GUI:-0}

# The testbench reads tb/*.hex relative to the project root.
cd "${PROJECT_DIR}"
mkdir -p output

. "${PROJECT_DIR}/scripts/with_cadence.sh"

if [ "$GUI" -eq 1 ]; then
    cadence_run "xrun -sv -access +rwc -timescale 1ns/1ps -top tb_fir4 \
        '${RTL}' '${TB}' -gui -input '${PROJECT_DIR}/scripts/sim_gui.tcl' \
        -log '${LOG}'"
    exit 0
fi

cadence_run "xrun -sv -access +rwc -timescale 1ns/1ps -top tb_fir4 \
    '${RTL}' '${TB}' -log '${LOG}'"

echo ""
grep -E "outputs matched|mismatch|Summary|TEST (PASSED|FAILED)" "${LOG}" || true

if grep -q "TEST PASSED" "${LOG}"; then
    echo "  RESULT: RTL SIM PASS"
else
    echo "  RESULT: RTL SIM FAIL -- review ${LOG}"
    exit 1
fi
