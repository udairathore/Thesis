module delay #(DATA_WIDTH=8, N=1) (
	input bit clk,
	input [DATA_WIDTH-1:0] din,
	output logic [DATA_WIDTH-1:0] dout
	);

	reg [DATA_WIDTH-1:0] sreg [0:N-1];
	integer i;

	generate
		if (N == 0) begin
			assign dout = din;
		end else begin
			always_ff @(posedge clk) begin
				for (i=N-1; i>0; i=i-1) begin
					sreg[i] <= sreg[i-1];
				end
				sreg[0] <= din;
			end
			assign dout = sreg[N-1];
		end
	endgenerate
	
endmodule



module wavefront_multi #(DATA_WIDTH=8, N=1) (
	input bit clk,
	input [DATA_WIDTH-1:0] din [0:N-1],
	output logic [DATA_WIDTH-1:0] dout [0:N-1]
	);

	genvar i;
	generate
		for (i=0; i<N; i++) begin : channel
			delay #(DATA_WIDTH, i) sreg(
				.clk(clk),
				.din(din[i]),
				.dout(dout[i])
			);
		end
	endgenerate

endmodule

module wavefront_broadcast #(DATA_WIDTH=8, N=1) (
	input bit clk,
	input [DATA_WIDTH-1:0] din,
	output logic [DATA_WIDTH-1:0] dout [0:N-1]
	);

	genvar i;
	generate
		for (i=0; i<N; i++) begin : channel
			delay #(DATA_WIDTH, i) sreg(
				.clk(clk),
				.din(din),
				.dout(dout[i])
			);
		end
	endgenerate
	
endmodule
