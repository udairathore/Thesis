`include "queue.sv"
`include "defs.sv"
`include "utils.sv"

module drain #(M=2, N=2) (
	input clk,
	input rst,

	input valid_in,
	input [`C_WIDTH-1:0] data_in [0:N-1],

	output logic [`C_STREAM_WIDTH-1:0] data_out,
	output logic valid_out
	);

	parameter ENQ_II = 2; // must match II in the testbench
	parameter DRAIN_STAGES = N/`C_WORDS_PER_BEAT;
	parameter DEQ_II = `C_WORDS_PER_BEAT;

	// 
	initial begin
		if (N%`C_WORDS_PER_BEAT != 0) begin
      		$error($sformatf("Illegal values for parameters N (%0d) and C_WORDS_PER_BEAT (%0d)", N, `C_WORDS_PER_BEAT));
      		$finish;
    	end
    end

	// stream reshape and bundle
	logic [`C_STREAM_WIDTH-1:0] data_reshaped [0:DRAIN_STAGES-1];
	logic [`C_STREAM_WIDTH-1:0] data_buffer [0:DRAIN_STAGES-1];
	logic valid_in_buffer [0:DRAIN_STAGES-1];
	logic valid_out_buffer [0:DRAIN_STAGES-1];
	logic ready_buffer;

	genvar i,j;
	generate
		// reshape wavefront array
		for (i=0; i<DRAIN_STAGES; i++) begin : stages
			logic [`C_STREAM_WIDTH-1:0] c_beat;
			for (j=0; j<`C_WORDS_PER_BEAT; j++) begin : beat
				logic [`C_WIDTH-1:0] c_word;
				delay #(`C_WIDTH, `C_WORDS_PER_BEAT-1-j) sreg(clk, data_in[i*`C_WORDS_PER_BEAT + j], c_word); 
				assign c_beat[`C_WIDTH*(j+1)-1:`C_WIDTH*j] = c_word;
			end
			assign data_reshaped[i] = c_beat;

		// buffer and synchronise reshaped wavefront array
			delay #(1, i*`C_WORDS_PER_BEAT+`C_WORDS_PER_BEAT - 1) sreg_vld(clk, valid_in, valid_in_buffer[i]);
			queue_shifter #(`C_STREAM_WIDTH, 64, `C_WORDS_PER_BEAT*DRAIN_STAGES - `C_WORDS_PER_BEAT*i - (`C_WORDS_PER_BEAT-1)) buffer(
				.clk(clk),
				.rst(rst),
				.data_in(data_reshaped[i]),
				.valid_in(valid_in_buffer[i]),
				.ready_in(),
				.data_out(data_buffer[i]),
				.valid_out(valid_out_buffer[i]),
				.ready_out(ready_buffer),
				.count()
			);
		end
	endgenerate

	// shift the data out
	parallel_to_serial #(`C_STREAM_WIDTH, DRAIN_STAGES) piso(
		.clk(clk),
		.rst(rst),
		.valid_in(valid_out_buffer[0]),
		.data_in(data_buffer),
		.ready_in(ready_buffer),
		.data_out(data_out),
		.valid_out(valid_out)
	);


endmodule