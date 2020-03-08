`include "dp_ram.sv"
`include "defs.sv"

module feeder (
	clk,										//clock transition for fsm 
	rst,										//used to reset the whole fsm
	valid_write,								//determines when to write and when not to write --> probably based on write full??
	start,										//probably use it to determine when is the first time you are writing after reset, does not change once started
	data_in,
	data_out,
	counter_write,
	state_current,
	wr_en,
	last,
	ram_full,
	rd_idx,
	stride,
	chans_per_mem,
	In_cols,
	In_finish,
	k_dimension,
	o_dimension
	);

////////////////////////////////////////PARAMETERS////////////////////////////////////////

	parameter ADDR_WIDTH = 16;
	parameter DATA_WIDTH = 16;
 ////////////////////////////////////////FSM STATES////////////////////////////////////////
	parameter NO_USE = 2'b00; 
	parameter IDLE_WRITE = 2'b01;
	parameter START = 2'b10;
	parameter REUSE_WRITE = 2'b11;	
	parameter IDLE_READ = 1'b0;
	parameter REUSE_READ = 1'b1;

////////////////////////////////////////PORT DEFINITIONS////////////////////////////////////////

	input [DATA_WIDTH - 1 : 0] data_in;
	input clk;										//clock transition for fsm 
	input rst;										//used to reset the whole fsm
	input valid_write;								//determines when to write and when not to write --> probably based on write full??
	input start;									//probably use it to determine when is the first time you are writing after reset, does not change once started
	input [1:0] stride;
	input [ADDR_WIDTH-1:0] chans_per_mem;
	input [ADDR_WIDTH-1:0] In_cols;
	input [ADDR_WIDTH-1:0] k_dimension;
	input [ADDR_WIDTH-1:0] o_dimension;
	output [ADDR_WIDTH-1 :0] counter_write;
	output [1:0] state_current;
	output wr_en;
	output ram_full;
	output [ADDR_WIDTH-1:0] last; 
	output [ADDR_WIDTH-1 : 0] rd_idx;
	output In_finish;
	output [DATA_WIDTH - 1: 0] data_out;


////////////////////////////////////////Logic and Assign////////////////////////////////////////
	logic wr_enable;														//enable writing to ram
	assign wr_en = wr_enable;												//for output	

	logic last_out = 0;
	assign In_finish = last_out;

	logic [1:0] stride_multiplier;
	assign stride_multiplier = (stride==2'b01) ? 2'b10 : 2'b01; 			//very important 

	logic[DATA_WIDTH -1 : 0] row_beg1;										//pointer to the begining of row 1
	logic[DATA_WIDTH -1 : 0] row_beg2;										//pointer to the begging of row 2
	logic[DATA_WIDTH -1 : 0] row_beg3; 										//pointer to the begining of row 3
	logic[DATA_WIDTH -1 : 0] last_idx;										//pointer to last index that needs to be written/read to/from
	assign row_beg1 = In_cols * chans_per_mem;
	assign row_beg2 = row_beg1 + row_beg1; 
	assign row_beg3 = row_beg2 + row_beg1;
	assign last_idx = (row_beg3 + row_beg1) - 1;
	assign last = last_idx;													//for output 

	logic [ADDR_WIDTH-1 : 0] total_horizontal_read;
	assign total_horizontal_read = (k_dimension * k_dimension * chans_per_mem * o_dimension) - 1;

	logic [ADDR_WIDTH-1:0] stride_write;
	assign stride_write = (total_horizontal_read - (row_beg1 * stride)) - 2;

	logic[ADDR_WIDTH-1:0] feed_row;
	assign feed_row = k_dimension * chans_per_mem;

	logic write_full;
	assign ram_full = write_full;											//for output 

	logic [ADDR_WIDTH -1:0] row_index;
	assign counter_write = row_index;										//For output 

	logic [1:0] row_reuse;

	logic [1:0] state;
	assign state_current = state; 											//for output	
	logic [1:0] next_state;

	logic [1:0] read_state;
	logic [1:0] next_read_state; 
	logic [ADDR_WIDTH - 1:0] read_index; 
	assign rd_idx = read_index;												//for output 
	
	logic [ADDR_WIDTH-1:0] horizontal_ctr;									
	logic [ADDR_WIDTH-1:0] row_ctr;
	logic [ADDR_WIDTH-1:0] verical_ctr; 									
	logic [DATA_WIDTH : 0] horizontal_read_count = 0;
	logic [ADDR_WIDTH-1 : 0] output_verical_ctr = 0;
	logic stride_flag = 1'b1;												// HAS TO BE SET TO 1 for stride 
	logic valid_read; 



////////////////////////////////////////FSM state definition for writing////////////////////////////////////////
	always @ (state or rst or start or write_full or valid_write)
	begin : FSM_COMBO
 
		case (state)
			NO_USE		:	if (start && (!rst) && (!write_full) && valid_write) begin				// if start go into start 	
								wr_enable = 1;//FOR TESTING ONLY
								next_state = START;
							end else begin															//if start is 0 and reset is 0 stay in no use
								wr_enable = 0;
								next_state = NO_USE;
							end
			START		:	if(rst || (!valid_write)) begin
								next_state = NO_USE;
							end else if ((!write_full) && valid_write) begin 						//if write is full, or if data not valid or if reset is true then go into idle  
								next_state = START;								
							end else if (write_full) begin											//otherwise stay in start mode 
								wr_enable = 0;
								next_state = IDLE_WRITE;
							end
			IDLE_WRITE 	:	if (rst || (!valid_write)) begin										//if reset then go to no_use 
								next_state = NO_USE;
							end else if (!write_full && valid_write) begin							// if writing is valid then go to reuse state gh
								wr_enable = 1;
								next_state = REUSE_WRITE;
							end else if (write_full) begin
								next_state = IDLE_WRITE;
							end
			REUSE_WRITE :	if (rst || (!valid_write)) begin
								next_state = NO_USE;
							end else if ((!write_full) && valid_write) begin
								next_state = REUSE_WRITE;
							end else if (write_full) begin
								wr_enable = 0;
								next_state = IDLE_WRITE;
							end
		endcase
	end : FSM_COMBO

////////////////////////////////////////FSM transition for writing////////////////////////////////////////
	// seq logic
	always_ff @(posedge clk) begin : state_transition
		if(rst) begin
			state <= NO_USE;
		end else begin
			state <= next_state;
		end
	end
////////////////////////////////////////FSM output for writing////////////////////////////////////////
// output
	always_ff @(posedge clk) begin : out_transition
		if(rst) begin
			row_index <= 0;
			row_reuse <= 0;
			write_full <=0;
		end else begin
			case(state)
				IDLE_WRITE	:	begin
									if (!write_full) begin
										if(row_index == last_idx) begin
											row_index = 0;
											row_reuse = row_reuse;
										end else begin 
											row_index = row_index + 1;
											row_reuse = row_reuse;
										end
									end else begin
										row_index = row_index;
										row_reuse = row_reuse;
									end
								end

				START 		: 	if (row_index == (row_beg3-1)) begin
									write_full = 1;  									//write full goes to one when I've finished writing what i have intended to write. 
									row_index = row_beg3;								//set write pointer to begining of the 4th row for reuse write 
									row_reuse = 2; 										//2nd row is going to be reused for STRIDE-2!!!
									valid_read = 1;
									read_index = 0; 
								end else if (!write_full) begin
									row_index = row_index + 1;
								end	
				NO_USE  	:	begin
									row_index = 0;
									row_reuse = 0;
									write_full = 0; 
								end
				REUSE_WRITE : 	if (row_reuse == 0) begin
									if(row_index == (row_beg2-1)) begin
										write_full = 1;
										row_index = row_beg2;							//if fuck up in index writing change this
									end else if (row_index == (row_beg3 - 1)) begin
										write_full = 1;
										row_index = row_beg3;
										row_reuse = 2;
									end else if(!write_full) begin
										row_index = row_index + 1; 
									end
								end else begin
									if (row_index == (row_beg1 - 1)) begin
										write_full = 1;
										row_index = row_beg1;							//if fuck up in index writing change this
										row_reuse = 0;
									end else if(row_index == last_idx) begin
										write_full = 1;
										row_index = 0; 
									end else if (!write_full) begin
										row_index = row_index + 1; 
									end
								end
			endcase
		end
	end


////////////////////////////////////////FSM states and transition for reading////////////////////////////////////////
	always @ (valid_read or rst)
	begin : FSM_COMBO_READ
 
		case (read_state)
			IDLE_READ	:	if ((!rst) && valid_read) begin								// if start go into start 	
								next_read_state = REUSE_READ;
							end else begin												//if start is 0 and reset is 0 stay in no use
								next_read_state = IDLE_READ;
							end
			REUSE_READ	:	if(rst || (!valid_read)) begin
								next_read_state = IDLE_READ;
							end else if (valid_read) begin 								//if write is full, or if data not valid or if reset is true then go into idle  
								next_read_state = REUSE_READ;								 
							end 
		endcase
	end : FSM_COMBO_READ
////////////////////////////////////////FSM transition for reading////////////////////////////////////////
	// seq logic
	always_ff @(posedge clk) begin : state_transition_read
		if(rst) begin
			read_state <= IDLE_READ;
		end else begin
			read_state <= next_read_state;
		end
	end



////////////////////////////////////////FSM output for reading////////////////////////////////////////
// output
	always_ff @(posedge clk) begin : out_transition_read
		if(rst) begin
			valid_read <= 0;
			verical_ctr <= 0;
			horizontal_ctr <=0;
			row_ctr <=0;
			output_verical_ctr = 0;
			read_index = 0;
			horizontal_read_count = 0;
		end else begin
			case(read_state)
				IDLE_READ	:	begin
										read_index = read_index;
										verical_ctr = verical_ctr;
										horizontal_ctr = horizontal_ctr;
										output_verical_ctr = output_verical_ctr;
										last_out = 0;

								end

				REUSE_READ	:	if (output_verical_ctr < o_dimension) begin
									if (row_ctr < (feed_row-1)) begin 										//change this if index fuck up!!!
										read_index = read_index + 1;
										row_ctr = row_ctr + 1;
										horizontal_read_count = horizontal_read_count + 1;
										if ((horizontal_read_count >= stride_write) && (horizontal_read_count < (total_horizontal_read - 2))) begin
											write_full = 0;
										end
									end else if (row_reuse == 2) begin
										if (verical_ctr == 0) begin
											read_index = (read_index + row_beg1) - (feed_row-1);
											verical_ctr = verical_ctr + 1;
											row_ctr = 0;
											horizontal_read_count = horizontal_read_count + 1;
										end else if (verical_ctr == 1) begin
											read_index = (read_index + row_beg1) - (feed_row-1);			//add one row and subtract one feed row value 
											verical_ctr = verical_ctr + 1;
											row_ctr = 0;
											horizontal_read_count = horizontal_read_count + 1;
										end else if (verical_ctr == 2) begin
											horizontal_ctr = horizontal_ctr + 1;
											if (horizontal_ctr < (o_dimension)) begin	
												read_index <= read_index - (row_beg1 + row_beg1) - ((chans_per_mem * (stride_multiplier)) -1) ;
												verical_ctr = 0;
												row_ctr = 0;
												horizontal_read_count = horizontal_read_count + 1;
											end else if (stride == 2'b01 && stride_flag) begin
												read_index = row_beg1;
												horizontal_ctr = 0;
												output_verical_ctr = output_verical_ctr + 1;
												horizontal_read_count = 0;
												row_ctr = 0;
												verical_ctr = 0;
												stride_flag = 0;
											end else begin
												read_index = 0;
												horizontal_ctr = 0;
												output_verical_ctr = output_verical_ctr + 1;
												horizontal_read_count = 0;
												row_ctr = 0;
												verical_ctr = 0;
												stride_flag = 1; 
											end
										end
									end else if (row_reuse == 0) begin
										if (verical_ctr == 0) begin
											if (stride_flag == 0) begin
												read_index <= 0 + (horizontal_ctr*(feed_row-(chans_per_mem * (stride_multiplier))));
												verical_ctr = verical_ctr + 1;
												row_ctr = 0;
												horizontal_read_count = horizontal_read_count + 1;
											end else begin
												read_index = (read_index + row_beg1) - (feed_row-1);
												verical_ctr = verical_ctr + 1;
												row_ctr = 0;
												horizontal_read_count = horizontal_read_count + 1;
											end
										end else if (verical_ctr == 1) begin
											if (stride_flag == 0) begin
												read_index = (read_index + row_beg1) - (feed_row-1);
												verical_ctr = verical_ctr + 1;
												row_ctr = 0; 
												horizontal_read_count = horizontal_read_count + 1;
											end else begin
												read_index <= 0 + (horizontal_ctr*(feed_row-(chans_per_mem * (stride_multiplier))));
												verical_ctr = verical_ctr + 1;
												row_ctr = 0;
												horizontal_read_count = horizontal_read_count + 1;
											end
										end else if (verical_ctr == 2) begin
											horizontal_ctr = horizontal_ctr + 1;
											if (horizontal_ctr < o_dimension) begin
												if (stride_flag == 1) begin
													read_index <= row_beg2 + (horizontal_ctr * (feed_row-(chans_per_mem * (stride_multiplier))));
													verical_ctr = 0;
													row_ctr = 0;
													horizontal_read_count = horizontal_read_count + 1;
												end else if (stride_flag == 0) begin
													read_index <= row_beg3 + (horizontal_ctr * (feed_row-(chans_per_mem * (stride_multiplier))));
													verical_ctr = 0;
													row_ctr = 0;
													horizontal_read_count = horizontal_read_count + 1;
												end
											end else if (stride == 2'b01 && stride_flag) begin
												read_index = row_beg3;
												horizontal_ctr = 0;
												output_verical_ctr = output_verical_ctr + 1;
												horizontal_read_count = 0;
												row_ctr = 0;
												verical_ctr = 0;
												stride_flag = 0;
											end else begin
												read_index = row_beg2;
												horizontal_ctr = 0;
												output_verical_ctr = output_verical_ctr + 1;
												horizontal_read_count = 0;
												row_ctr = 0;
												verical_ctr = 0;
												stride_flag = 1;											
											end
										end
									end
								end else begin
									last_out = 1;
									output_verical_ctr = 0;
									read_index = 0;
									row_ctr = 0;
									horizontal_ctr = 0;
									horizontal_read_count = 0;
									verical_ctr = 0;
								end

			endcase
		end
	end
////////////////////////////////////////Connections to dual port RAM////////////////////////////////////////
sync_dp_ram #(DATA_WIDTH, ADDR_WIDTH) mem (
	.data_a(data_in), 
	.data_b(),
	.addr_a(row_index), 
	.addr_b(read_index),
	.we_a(wr_enable), 
	.we_b(), 
	.clk(clk),
	.q_a(), 	
	.q_b(data_out)
);

endmodule : feeder