`include "defs.sv" 

module kernel_mac #(OP_WIDTH=8, ACC_WIDTH=20, LANES=1) (
	input clk, // not used here
	input rst, // not used here
	input [0:LANES-1][OP_WIDTH-1:0] weights,					//Weights in memory 
	input [0:LANES-1][OP_WIDTH-1:0] iacts,						//Input Tensor 	
	input [0:LANES-1][ACC_WIDTH-1:0] psums,						//Bias/Partial Sum from other PE coming in
	output logic [0:LANES-1][ACC_WIDTH-1:0] outputs
	);

	// latency
	parameter LATENCY = 3;
	
	// define pipeline stages
	logic [0:LANES-1][OP_WIDTH-1:0] op1;
	logic [0:LANES-1][OP_WIDTH-1:0] op2; 
	logic [0:LANES-1][ACC_WIDTH-1:0] mult;

	genvar i;
	generate
		for (i=0; i<LANES; i++) begin

			always_ff @(posedge clk) begin : mac
				if(rst) begin
					op1[i] <= 0;
					op2[i] <= 0;
				end else begin
					op1[i] <= iacts[i];
					op2[i] <= weights[i];
				end
				mult[i] <=  $signed(op1[i]) * $signed(op2[i]);
				outputs[i] <= mult[i] + psums[i];
			end
									
		end
	endgenerate

endmodule