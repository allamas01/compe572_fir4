# =============================================================================
# fir4.sdc -- Timing constraints for 300 MHz target
# All times in ns, capacitance in pF.
# =============================================================================

# Design rules: limit loading and slow edges on every net
set_max_fanout     20   [current_design]
set_max_transition 0.20 [current_design]

# Clock: 3.333 ns period = 300 MHz, 50% duty cycle
create_clock -name clk -period 3.333 -waveform {0 1.667} [get_ports clk]

# Margin for jitter/skew: more pessimistic for setup than hold
set_clock_uncertainty -setup 0.05 [get_clocks clk]
set_clock_uncertainty -hold  0.03 [get_clocks clk]
set_clock_transition         0.05 [get_clocks clk]

# Do not buffer or resize the clock net during synthesis (CTS builds it later)
set_dont_touch_network [get_clocks clk]

# Inputs arrive late: 0.67 ns (20% of period) after the clock edge at most
# (-max checks setup), and no earlier than 0.05 ns (-min checks hold)
set_input_delay -max 0.70 -clock clk [get_ports rst_b]
set_input_delay -min 0.05 -clock clk [get_ports rst_b]
set_input_delay -max 0.67 -clock clk [get_ports valid_in]
set_input_delay -min 0.05 -clock clk [get_ports valid_in]
set_input_delay -max 0.67 -clock clk [get_ports {x[*]}]
set_input_delay -min 0.05 -clock clk [get_ports {x[*]}]

# Outputs: the next chip needs 0.67 ns of the cycle for its own setup
set_output_delay -max 0.67 -clock clk [get_ports {y[*]}]
set_output_delay -min 0.05 -clock clk [get_ports {y[*]}]
set_output_delay -max 0.67 -clock clk [get_ports valid_out]
set_output_delay -min 0.05 -clock clk [get_ports valid_out]

# Each output drives 5 fF (one small gate)
set_load 0.005 [all_outputs]

# Async reset is not timed against clk
set_false_path -from [get_ports rst_b]

# Scan/test ports are inactive in normal operation: tie to 0, skip timing
set_case_analysis 0 [get_ports scan_en]
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports scan_en]
set_false_path -from [get_ports test_mode]
set_false_path -from [get_ports scan_in]
set_false_path -to   [get_ports scan_out]
