create_clock -period 20.000 -name sys_clk [get_ports clk]
set_property BITSTREAM.GENERAL.UNCONSTRAINEDPINS {Allow} [current_design]
