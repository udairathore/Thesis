//-----------------------------------------------------
// multiply-accumulate kernel
//-----------------------------------------------------
`include "defs.sv" 

module accumulator #(DATA_WIDTH=8, CTRL_WIDTH=9) (
	input clk,
	input rst,
	input [CTRL_WIDTH-1:0] ctrl,
	input [DATA_WIDTH-1:0] psum,
	output [DATA_WIDTH-1:0] data_out,
	output logic valid_out
	);
	
	logic [DATA_WIDTH-1:0] result;
	wire [DATA_WIDTH-1:0] temp;
	logic valid_in, last;
	logic [CTRL_WIDTH-1:0] ctrl_sr;

	delay #(CTRL_WIDTH, `RAM_READ_LATENCY+2) ctrl_sreg(clk, ctrl, ctrl_sr); // 4 = PE_LATENCY (from ctrl) = RAM_RD + MUL cycle + Acc cycle



	assign valid_in = ctrl_sr[0];
	assign first = ctrl_sr[8];
	assign last = ctrl_sr[7];
	assign temp = first ? {DATA_WIDTH{1'b0}} : result;
	
	always_ff @(posedge clk) begin : acc
		if(rst) begin
			result <= 0;
		end else if(valid_in) begin
			result <= psum + temp;
		end
	end

	always_ff @(posedge clk) begin : vld
		valid_out <= last;							//for when to know the acc is done doing one entire kernel 
	end
	
	assign data_out = result;

endmodule
