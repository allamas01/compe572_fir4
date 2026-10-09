// =============================================================================
// run_lec_synth.do -- Post-synthesis LEC (RTL vs Genus netlist)
// Run from fv/fir4/ (run_lec_synth.sh does the cd).
// =============================================================================

// Unknown cells become black boxes instead of stopping the read
set undefined cell black_box -both
set log file reports/lec_synth.log -replace

// Standard-cell models (Liberty), used for both designs
read library -liberty -both -statetable \
    ../../lib/slow_vdd1v0_basicCells.lib   \
    ../../lib/slow_vdd1v0_multibitsDFF.lib \
    ../../lib/fast_vdd1v0_basicCells.lib   \
    ../../lib/fast_vdd1v0_multibitsDFF.lib

// GOLDEN: original RTL
read design -sv -golden -replace ../../rtl/fir4.sv

// REVISED: Genus gate-level netlist (before P&R)
read design -verilog -revised -replace ../../output/fir4_netlist.v

// DFT: scan is off in normal operation, scan_out has no RTL equivalent
add pin constraint 0 scan_en            -golden      -revised
add pin constraint 0 test_mode          -golden      -revised
add pin constraint 0 scan_in            -golden      -revised
add ignored outputs scan_out            -golden      -revised
set undriven signal 0                   -golden      -revised

// Compare every flop and output between the two designs
set system mode lec
add compared points -all
compare

// Report (run_lec_synth.sh reads the EQ / NON-EQ counts from this file)
report verification -verbose > reports/lec_synth.rpt
report compare data -class nonequivalent -class abort >> reports/lec_synth.rpt
report unmapped points -golden -revised >> reports/lec_synth.rpt
report statistics >> reports/lec_synth.rpt
exit -f
