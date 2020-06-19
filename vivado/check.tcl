open_checkpoint outputs/post_route_feeder.dcp

set my_rams [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ *.bram.* }]
set doa_reg [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ *.bram.* && DOA_REG == "TRUE" }]

llength $my_rams
llength $doa_reg

puts stdout $my_rams
puts stdout [llength $doa_reg]