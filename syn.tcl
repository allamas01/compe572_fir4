# =============================================================================
# syn.tcl -- Genus synthesis flow (run from the project root)
#   genus -batch -f scripts/syn.tcl -log output/genus_fir4.log
# =============================================================================

# 1-2. Libraries, then read + elaborate RTL
source [file join [file dirname [info script]] setup.tcl]
source [file join [file dirname [info script]] read_rtl.tcl]

# 3. Timing constraints
read_sdc ${PROJECT_DIR}/constraints/fir4.sdc

# Effort: high for all three synthesis phases
set_db syn_generic_effort high
set_db syn_map_effort     high
set_db syn_opt_effort     high

# CRITICAL: no retiming, no ungrouping (keeps truncation per stage, LEC-safe)
catch { set_db retime false }
catch { set_db syn_opt_retime false }
catch { set_db auto_ungroup none }

# DFT: muxed scan, shift enable / test mode / test clock
set_db dft_scan_style muxed_scan
define_dft shift_enable -name scan_en   -active high [get_ports scan_en]
define_dft test_mode    -name test_mode -active high [get_ports test_mode]
define_dft test_clock   -name clk                    [get_ports clk]

# 4-6. Generic -> technology map -> optimize
syn_generic
syn_map
syn_opt

# 7. Scan insertion: replace flops with scan flops, stitch one chain
check_dft_rules
convert_to_scan
define_dft scan_chain -name fir4_chain1 \
    -sdi scan_in -sdo scan_out -non_shared_output -shift_enable scan_en
connect_scan_chains
write_scandef > ${OUT_DIR}/${DESIGN_NAME}_scan.def

# 8. Replace Verilog assign statements with buffers, keep those buffers
set_db / .remove_assigns true
remove_assigns_without_optimization
catch {
    set _assign_bufs [get_db insts -if {.name == *assign*}]
    if {[llength $_assign_bufs] > 0} { set_db $_assign_bufs .dont_touch true }
}

# 9. Outputs for LEC, Innovus, GLS
write_hdl > ${OUT_DIR}/${DESIGN_NAME}_netlist.v
write_sdc > ${OUT_DIR}/${DESIGN_NAME}_out.sdc
write_sdf -timescale ns -nonegchecks > ${OUT_DIR}/${DESIGN_NAME}.sdf

# Reports
report_timing -max_paths 10 > ${OUT_DIR}/${DESIGN_NAME}_timing.rpt
report_area                 > ${OUT_DIR}/${DESIGN_NAME}_area.rpt
report_gates                > ${OUT_DIR}/${DESIGN_NAME}_gates.rpt
report_power                > ${OUT_DIR}/${DESIGN_NAME}_power.rpt
report_qor                  > ${OUT_DIR}/${DESIGN_NAME}_qor.rpt
catch { report_scan_chains  > ${OUT_DIR}/${DESIGN_NAME}_scan.rpt }

puts "syn.tcl: synthesis complete"
