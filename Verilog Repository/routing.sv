`include "defs.sv"


module rtr_systolic_general #(I_WIDTH=8, W_WIDTH=8, P_WIDTH=20, CTRL_WIDTH=9) (
	input clk,
	// global
	input [CTRL_WIDTH-1:0] global_ctrl_in,
	output logic [CTRL_WIDTH-1:0] global_ctrl_out,
	input [I_WIDTH-1:0] global_iact_in,
	output logic [I_WIDTH-1:0] global_iact_out,
	input [P_WIDTH-1:0] global_psum_in,
	output logic [P_WIDTH-1:0] global_psum_out,
	// local
	output logic [CTRL_WIDTH-1:0] local_ctrl_out,
	output logic [I_WIDTH-1:0] local_iact_out,
	output logic [P_WIDTH-1:0] local_psum_out,
	input [P_WIDTH-1:0] local_psum_in
	);

	always_ff @(posedge clk) begin : systolic
		global_iact_out <= global_iact_in;
		global_ctrl_out <= global_ctrl_in; 
	end

	assign local_psum_out = global_psum_in;
	assign global_psum_out = local_psum_in;
	assign local_iact_out = global_iact_in;
	assign local_ctrl_out = global_ctrl_in;

endmodule
