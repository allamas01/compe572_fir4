# =============================================================================
# read_rtl.tcl -- Read, elaborate, and protect RTL hierarchy
# Expects setup.tcl to have been sourced (PROJECT_DIR, TOP_MODULE).
# =============================================================================

set RTL_DIR ${PROJECT_DIR}/rtl

# Keep the three pipeline stages as separate modules
catch { set_db auto_ungroup none }

# -define DFT_INSERTION: skip the "scan_out = 0" tie in the RTL so
# connect_scan_chains can drive scan_out later
read_hdl -language sv -define DFT_INSERTION [list \
    ${RTL_DIR}/fir4.sv \
]

elaborate ${TOP_MODULE}
check_design -unresolved
check_design -multiple_driver

# Protect pipeline stages from ungrouping/restructuring across boundaries
foreach inst {u_stage1 u_stage2 u_stage3} {
    catch {
        set cell [get_cells $inst]
        if {$cell ne ""} {
            set_dont_touch $cell true
        }
    }
}
foreach mod {fir4_stage1 fir4_stage2 fir4_stage3} {
    catch {
        set d [get_designs $mod]
        if {$d ne ""} { set_dont_touch $d true }
    }
}
