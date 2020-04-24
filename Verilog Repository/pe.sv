`include "defs.sv" 
//`include "mem/core.sv"
`include "mac.sv"

module pe_ws #(OP_WIDTH=8, ACC_WIDTH=20, CTRL_WIDTH=9, MEM_INIT="zero.txt") (
	input clk,
	input rst, 

	// ctrl NOC
	input [CTRL_WIDTH-1:0] ctrl,
	
	// input NOC
	input [OP_WIDTH-1:0] iact,

	//weight NOC
	input wctrl,
	input [OP_WIDTH-1:0] weight,

	// psum NOC
	input [ACC_WIDTH-1:0] psum_in,
	output logic [ACC_WIDTH-1:0] psum_out 
	
	);

	parameter ADDR_WIDTH=10;
	parameter DATA_WIDTH=OP_WIDTH;

	// inter-connections
	logic [OP_WIDTH-1:0] wdata;
	logic [ADDR_WIDTH-1:0] wr_pointer;
	logic [ADDR_WIDTH-1:0] rd_pointer;
	logic read_valid, read_reset, write_valid;

	assign read_valid = ctrl[0];
	assign read_reset = ctrl[7];
	assign write_valid = wctrl;
	
	always_ff @(posedge clk) begin : read_incr
		if(rst) begin
			rd_pointer <= 0;
		end else if (read_valid) begin
			if (read_reset) begin
				rd_pointer <= 0;
			end else begin
				rd_pointer <= rd_pointer + 1;
			end
		end
	end

	always_ff @(posedge clk) begin : write_incr
		if(rst) begin
			wr_pointer <= 0;
		end else if (write_valid) begin
			wr_pointer <= wr_pointer + 1;
		end else begin
			wr_pointer <= wr_pointer;
		end
	end


	sync_dp_ram #(DATA_WIDTH, ADDR_WIDTH, MEM_INIT) ram_weights(
		.clk(clk),
		// port A
		.data_a(),
		.q_a(),
		.addr_a(),
		.we_a(write_valid),
		// port B
		.data_b(),
		.q_b(wdata),
		.addr_b(rd_pointer),
		.we_b()
	);


	// computation
	kernel_mac #(OP_WIDTH, ACC_WIDTH, 1) mac(
		.clk(clk),
		.rst(rst),
		.weights(wdata),
		.iacts(iact),
		.psums(psum_in),
		.outputs(psum_out)
	);


endmodule