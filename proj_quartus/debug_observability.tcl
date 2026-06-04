# Board-agnostic Quartus debug setup for the RISC-V pipeline.
#
# Run from the repository root:
#   quartus_sh -t proj_quartus/debug_observability.tcl
#
# Or run from this directory:
#   quartus_sh -t debug_observability.tcl
#
# Optional arguments:
#   quartus_sh -t debug_observability.tcl <project_name> <revision_name>
#
# The helper only marks existing top-level debug outputs as virtual pins. It
# does not assign package pins, create a SignalTap file, or assume a board.

package require ::quartus::project

if {![info exists quartus(args)]} {
	set quartus(args) {}
}

set script_dir [file dirname [file normalize [info script]]]
set project_name "RISC_V_Single_Cycle"
set revision_name "RISC_V_Single_Cycle"

if {[llength $quartus(args)] >= 1} {
	set project_name [lindex $quartus(args) 0]
}

if {[llength $quartus(args)] >= 2} {
	set revision_name [lindex $quartus(args) 1]
}

cd $script_dir

if {[catch {project_open -revision $revision_name $project_name} open_error]} {
	post_message -type error "Could not open Quartus project '$project_name' revision '$revision_name': $open_error"
	qexit -error
}

set debug_virtual_pins {
	{debug_pc_o[*]}
	{debug_instruction_o[*]}
	{debug_wb_reg_write_o}
	{debug_wb_rd_o[*]}
	{debug_wb_data_o[*]}
	{debug_t0_o[*]}
	{debug_t1_o[*]}
	{debug_t2_o[*]}
	{debug_s0_o[*]}
	{debug_s1_o[*]}
	{debug_s2_o[*]}
	{debug_s3_o[*]}
}

foreach node $debug_virtual_pins {
	set_instance_assignment -name VIRTUAL_PIN ON -to $node
}

export_assignments

post_message "Applied virtual-pin assignments for board-agnostic debug outputs."
post_message "Use 'clk' as the SignalTap sample clock after assigning it for your board."
post_message "Suggested SignalTap probes: debug_pc_o, debug_instruction_o, debug_wb_reg_write_o, debug_wb_rd_o, debug_wb_data_o, debug_t0_o, debug_t1_o, debug_t2_o, debug_s0_o, debug_s1_o, debug_s2_o, debug_s3_o."

project_close
