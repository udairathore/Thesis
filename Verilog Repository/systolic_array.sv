`include "defs.sv" 
`include "utils.sv"
`include "routing.sv"


/*
# Systolic array of MxN PEs, weight stationary, wavefront
# Inputs (west to east), psums (north to south)
# **Note: iact input is already time-delayed as wavefront stream
*/  
module systolic #(M=2, N=2) (
	input clk,
	input rst, 

	input [`CTRL_WIDTH-1:0] ctrl,
	input [`B_WIDTH-1:0] iact [0:M-1],

	output logic [`C_WIDTH-1:0] psum [0:N-1],

	input [`CTRL_WIDTH-1:0] wctrl [0:N-1][0:M-1],
	input [`A_WIDTH-1:0] weights [0:N-1][0:M-1],

	output logic valid_out [0:N-1]

	);

	// broadcast ctrl as wavefront
	logic [`CTRL_WIDTH-1:0] wave_ctrl [0:M];
	wavefront_broadcast #(`CTRL_WIDTH, M+1) ctrl_feeder(clk, ctrl, wave_ctrl);
	
	// router-to-router mesh wires
	logic [`CTRL_WIDTH-1:0] global_ctrl [M+1][N+1];
	logic [`B_WIDTH-1:0] global_iact [M][N+1];
	logic [`C_WIDTH-1:0] global_psum [M+1][N];
	
	// router-to-pe wires
	logic [`CTRL_WIDTH-1:0] local_ctrl [M+1][N];
	logic [`B_WIDTH-1:0] local_iact [M][N];
	logic [`C_WIDTH-1:0] local_pin [M][N];
	logic [`C_WIDTH-1:0] local_pout [M][N];

	
	genvar i,j;
	generate
		// left feeder
		for (i=0; i<M; i=i+1) begin : row_feeder
			assign global_ctrl[i][0] = wave_ctrl[i];
			assign global_iact[i][0] = iact[i];
		end

		// top feeder
		for (j=0; j<N; j=j+1) begin : col_feeder
			assign global_psum[0][j] = `C_WIDTH'b0;
		end

		// mesh network
		for (i=0; i<M; i=i+1) begin : row
			for (j=0; j<N; j=j+1) begin : col

				rtr_systolic_general #(`B_WIDTH, `B_WIDTH, `C_WIDTH, `CTRL_WIDTH) rtr_leaf(
					.clk(clk),
					.global_ctrl_in(global_ctrl[i][j]),
					.global_ctrl_out(global_ctrl[i][j+1]),
					.global_iact_in(global_iact[i][j]),
					.global_iact_out(global_iact[i][j+1]),
					.global_psum_in(global_psum[i][j]),
					.global_psum_out(global_psum[i+1][j]),
					.local_ctrl_out(local_ctrl[i][j]),
					.local_iact_out(local_iact[i][j]),
					.local_psum_out(local_pin[i][j]),
					.local_psum_in(local_pout[i][j])				
				);

				pe_ws #(`B_WIDTH, `C_WIDTH, `CTRL_WIDTH, $sformatf("%spe_%0d%0d.txt",`DATA_PATH, i,j)) pe(
					.clk(clk),
					.rst(rst),
					.ctrl(local_ctrl[i][j]),
					.iact(local_iact[i][j]),
					.wctrl(wctrl[j][i]),
					.weight(weights[j][i]),
					.psum_in(local_pin[i][j]),
					.psum_out(local_pout[i][j])
				);

			end
		end

		// bottom drain
		for (j=0; j<N; j=j+1) begin : col_drain
			assign psum[j] = global_psum[M][j]; // output
		end

		// Accumulator
		/*
		assign global_ctrl[M][0] = wave_ctrl[M];
		for (j=0; j<N; j=j+1) begin : col_accumulator

			rtr_systolic_general #(`B_WIDTH, `B_WIDTH, `C_WIDTH, `CTRL_WIDTH) rtr_acc(
				.clk(clk),
				.global_ctrl_in(global_ctrl[M][j]),
				.global_ctrl_out(global_ctrl[M][j+1]),
				.local_ctrl_out(local_ctrl[M][j])
			);

			accumulator #(`C_WIDTH, `CTRL_WIDTH) acc(
				.clk(clk),
				.rst(rst),
				.ctrl(local_ctrl[M][j]),
				.psum(global_psum[M][j]),
				.data_out(psum[j]),
				.valid_out(valid_out[j])
			);
		
		end*/
	endgenerate


endmodule