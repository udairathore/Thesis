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

module parallel_to_serial #(DATA_WIDTH=32, N=2) (
	input clk,
	input rst,
	input valid_in,
	input [DATA_WIDTH-1:0] data_in [0:N-1],
	output logic ready_in,
	output logic [DATA_WIDTH-1:0] data_out,
	output logic valid_out
	);
	
	integer ii;
	if (N>1) begin

		parameter COUNTER_WIDTH = $clog2(N);
		parameter bit [0:COUNTER_WIDTH] full_count = N;

		logic [DATA_WIDTH-1:0] shift_reg [0:N-1];
		logic [COUNTER_WIDTH-1:0] count;

		always_ff @(posedge clk) begin : shift
			if(rst) begin
				shift_reg <= '{default:0};
				count <= 0;
			end else if (ready_in && valid_in) begin

				// To make it compatible with Vivado compiler
				//shift_reg <= '{data_in[1:N-1], {DATA_WIDTH{1'b0}}};
				for (ii = 0; ii < (N-1); ii = ii + 1)begin
					shift_reg[ii] <= data_in[ii-1];
				end
				shift_reg[ii] <= {DATA_WIDTH{1'b0}};

				count <= count+1;
			end else if (!ready_in) begin
				
				// To make it compatible with Vivado compiler
				//shift_reg <= '{shift_reg[1:N-1], {DATA_WIDTH{1'b0}}};
				for (ii = 0; ii < (N-1); ii = ii + 1)begin
					shift_reg[ii] <= shift_reg[ii-1];
				end
				shift_reg[ii] <= {DATA_WIDTH{1'b0}};

				if (count == full_count-1) begin
					count <= 0;
				end else begin
					count <= count + 1;
				end
			end
		end

		assign ready_in = (count == 0);
		assign data_out = (ready_in && valid_in) ? data_in[0] : shift_reg[0];
		assign valid_out = (ready_in && valid_in) | (count > 0);

	end else begin
		assign data_out = data_in[0];
		assign valid_out = valid_in;
		assign ready_in = 1'b1;
	end

endmodule