#
# Compile script for Synthesis and Implementation 
#

set ::outputDir "./outputs"
file mkdir $::outputDir

set srcDir 			[lindex $argv 0] ; 
set device 			[lindex $argv 1] ; 		# Device
set topSource 		"${srcDir}/feeder.sv" ;	# Top source
set topMod "feeder" ;						# Top module name

# print arguments
puts stdout $topMod 
puts stdout $topSource
puts stdout $device


# get the part number
if {$device == "Pynq-Z1"} {
	set DEVICE "xc7z020clg400-1"
} elseif {$device == "RFSoC"} {
	set DEVICE "xczu28dr-ffvg1517-2-e"
} else {
	set DEVICE "xczu28dr-ffvg1517-2-e"
}


create_project -in_memory -part $DEVICE
#set_property target_language Verilog [current_project]

# import source files
add_files -norecurse $topSource
source ./reportTiming.tcl


synth_design -top $topMod -part $DEVICE -generic {M=8 N=16} -include_dirs {"../Verilog" "../Verilog/Memory"}
report_utilization -file "${::outputDir}/post_synth_utilisation.rpt"

#set_property DOA_REG 1 [get_cells -regexp {mem/ram_reg_bram_*} ]
#set_property DOB_REG 1 [get_cells -regexp {mem/ram_reg_bram_*} ] 
set_property DOA_REG 1 [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ *.bram.*}]
set_property DOB_REG 1 [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ *.bram.*}]

write_checkpoint -force "${::outputDir}/post_synth_feeder.dcp"
read_xdc clock.xdc
opt_design
place_design
route_design -directive Explore
write_checkpoint -force "${::outputDir}/post_route_feeder.dcp"

# reports
reportTiming "${outputDir}/post_route_critpath.rpt"
report_utilization -file "${::outputDir}/post_route_utilisation.rpt"
report_utilization -hierarchical -file "${::outputDir}/post_route_hierarchical.rpt"
report_timing -sort_by "slack" -delay_type "max" -max_paths 10 -nworst 1 -file "${outputDir}/post_route_timing.rpt"



