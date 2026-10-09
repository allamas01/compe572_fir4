# =============================================================================
# setup.tcl -- Library and LEF configuration for Genus
# =============================================================================

set DESIGN_NAME "fir4"
set TOP_MODULE  "fir4"
set SCRIPT_DIR  [file dirname [file normalize [info script]]]
set PROJECT_DIR [file dirname $SCRIPT_DIR]
set LIB_DIR     ${PROJECT_DIR}/lib
set LEF_DIR     ${PROJECT_DIR}/lef
set OUT_DIR     ${PROJECT_DIR}/output
file mkdir $OUT_DIR

# Timing libraries (slow corner): standard cells + banked flip-flops
set_db library [list \
    ${LIB_DIR}/slow_vdd1v0_basicCells.lib   \
    ${LIB_DIR}/slow_vdd1v0_multibitsDFF.lib \
]

# Physical abstracts: tech LEF (metal stack) + macro LEF (cell outlines).
# Do NOT also load gsclib045_multibitsDFF.lef (duplicate macros, PHYS-107).
set_db lef_library [list \
    ${LEF_DIR}/gsclib045_tech.lef  \
    ${LEF_DIR}/gsclib045_macro.lef \
]

# Dont-use: weakest drive-strength cells (first matching pattern wins)
foreach pattern {*/*X0 */*_X0 */*_0 */*D0BWP*} {
    set _du [get_lib_cells -quiet ${pattern}]
    if {[llength ${_du}] > 0} {
        set_dont_use ${_du}
        break
    }
}

# Dont-use: physical-only / special cells with no LEF abstract
foreach pattern {FILL* ISO*LX1* ISO*HX1* HSW*X1 FSW*X1 LS*X* BHD*} {
    set _du [get_lib_cells -quiet ${pattern}]
    if {[llength ${_du}] > 0} { set_dont_use ${_du} }
}

puts "setup.tcl: PROJECT_DIR=${PROJECT_DIR}"
puts "setup.tcl: libraries = [get_db library]"
