`include "dp_ram.sv"
`include "defs.sv"
`include "utils.sv"

module feeder #(M=8,N=16) (
	clk,										//clock transition for fsm 
	rst,										//used to reset the whole fsm
	valid_write,								
	start,										
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
	o_dimension,
	loop_ctrl,
	total_read
	);

////////////////////////////////////// computation parameters ///////////////////////////////
	parameter M_ARR = M;			//2
	parameter N_ARR = N;            //2   
	parameter LK = 1;//`K_MAT/`K_TL;	//Tiling for Batch 
	parameter LN = 1;//`N_MAT/`N_TL;	//Tiling for input channel 
	parameter LM = 1;//`M_MAT/`M_TL; 	// outer reuse of (N_TL x K_TL) tile in B
	parameter TM = `M_TL/N_ARR; 		 // inner reuse of (N_TL x 1) tile in B
	parameter TN = 1;//`N_TL/M_ARR; 	// number of partial dot-products (innermost loop)
	parameter TK = `K_TL;   			// reuse of (M_TL x N_TL) tile in A (columns of tile in B)



	// assert conditions
	initial begin
	    if ((LK <= 0) || (LN <= 0) || (LM <= 0)) begin
	      	$error("Illegal tile size LK=%0d LN=%0d LM=%0d", LK, LN, LM);
	    end
	    if ((TK <= 0) || (TN <= 0) || (TM <= 0)) begin
	      	$error("Illegal tile size TK=%0d TN=%0d TM=%0d", TK, TN, TM);
	    end
	    if (`B_STREAM_WIDTH != `B_WIDTH*M) begin
	    	$error("Illegal stream width B_STREAM_WIDTH=%0d B_WIDTH=%0d M=%0d", `B_STREAM_WIDTH, `B_WIDTH, M);
	    end
	end


////////////////////////////////////////PARAMETERS////////////////////////////////////////

	parameter ADDR_WIDTH = 10; //16;
	parameter DATA_WIDTH = 8 * `stream_width;
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
	
	output logic [`B_WIDTH -1:0] data_out [0:M-1];
	output logic [8:0] loop_ctrl;

	output [63:0] total_read;


///////////////////////////////////////Counter Definitions///////////////////////////////////////	

	(* DONT_TOUCH = "yes" *) logic [63:0] read_counter; 
	assign total_read = read_counter; 
	(* DONT_TOUCH = "yes" *) logic [DATA_WIDTH - 1: 0] buffer_data_out_0;

	(* DONT_TOUCH = "yes" *) logic [8-1:0] kernel_reuse_ctr;							//tm_counter 
	(* DONT_TOUCH = "yes" *) logic [8-1:0] batch_ctr;									//tk_counter
	(* DONT_TOUCH = "yes" *) logic [8-1:0] lm_counter;									//lm_counter for entire ROW reuse
	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1:0] horizontal_ctr;									//"t_kernel_counter"									
	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1:0] row_ctr;											//tn_counter (?)
	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1:0] verical_ctr; 									
	(* DONT_TOUCH = "yes" *) logic [8 : 0] horizontal_read_count;
	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1 : 0] output_verical_ctr;
	(* DONT_TOUCH = "yes" *) logic [1:0] row_reuse;

	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH - 1:0] read_index; 
	assign rd_idx = read_index;												//Read counter 

	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH -1:0] row_index;
	assign counter_write = row_index;										//Write Counter

	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1 : 0 ] temp_read_index; 							
	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1:0] prev_read_index; 
	(* DONT_TOUCH = "yes" *) logic [8-1:0] prev_temp_read_index; 
	
	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1 : 0] horizontal_o_dimension;
	assign horizontal_o_dimension = (k_dimension == 1) ? 1 : o_dimension;  

	(* DONT_TOUCH = "yes" *) logic wr_enable;														//enable writing to ram
	assign wr_en = wr_enable;												//for output	

	(* DONT_TOUCH = "yes" *) logic last_out = 0;
	assign In_finish = last_out;

	(* DONT_TOUCH = "yes" *) logic [1:0] stride_multiplier;
	assign stride_multiplier = (stride==2'b01) ? 2'b10 : 2'b01; 			//very important 

 	(* DONT_TOUCH = "yes" *) logic write_full;
	assign ram_full = write_full;											//for output 

///////////////////////////////////////////FLAG DEFINITIONS////////////////////////////////////////////////////////////
	(* DONT_TOUCH = "yes" *) logic stride_flag = 1'b1;												// HAS TO BE SET TO 1 for any stride initially
	(* DONT_TOUCH = "yes" *) logic valid_read; 
	(* DONT_TOUCH = "yes" *) logic padding_flag = 0;
	(* DONT_TOUCH = "yes" *) logic padding = 1'b1;
//////////////////////////////////////////////POINTER DEFINITIONS////////////////////////////////////////////////////
	(* DONT_TOUCH = "yes" *) logic[ADDR_WIDTH-1: 0] read_row_beg;
	(* DONT_TOUCH = "yes" *) logic[ADDR_WIDTH-1: 0] row_beg0;
	(* DONT_TOUCH = "yes" *) logic[ADDR_WIDTH-1: 0] row_beg1;																					//pointer to the begining of row 1
	(* DONT_TOUCH = "yes" *) logic[ADDR_WIDTH-1: 0] row_beg2;																					//pointer to the begging of row 2
	(* DONT_TOUCH = "yes" *) logic[ADDR_WIDTH-1: 0] row_beg3; 																					//pointer to the begining of row 3
	(* DONT_TOUCH = "yes" *) logic[ADDR_WIDTH-1: 0] last_idx;																					//pointer to last index that needs to be written/read to/from
	assign row_beg0 = (padding == 1'b0) ? 0 : (chans_per_mem);
	assign row_beg1 = (padding == 1'b0) ? (In_cols * chans_per_mem * `batch_size) : ((In_cols * chans_per_mem*`batch_size)+(chans_per_mem));
	assign row_beg2 = (padding == 1'b0) ? (row_beg1 + row_beg1) : (((row_beg1-(chans_per_mem)) + (row_beg1))); 
	assign row_beg3 = (padding == 1'b0) ? (row_beg2 + row_beg1) : (((row_beg2-(chans_per_mem)) + row_beg1));
	assign last_idx = (padding == 1'b0) ? ((row_beg3 + row_beg1) - 1) : ((((row_beg3-(chans_per_mem)) + row_beg1) - 1));
	assign last = last_idx;	
	assign read_row_beg = (padding == 1'b0) ? row_beg1 : (row_beg1 - (chans_per_mem)); 									//for padding the counter increment changes based on padding

	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1 : 0] total_horizontal_read;
	assign total_horizontal_read = ((((k_dimension * k_dimension * chans_per_mem * o_dimension)*`batch_size)*TM) - 1);

	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1:0] stride_write;
	assign stride_write = ((total_horizontal_read - (read_row_beg * stride)) - 4);

	(* DONT_TOUCH = "yes" *) logic[ADDR_WIDTH-1:0] feed_row;
	assign feed_row = (k_dimension != 1) ? (k_dimension * chans_per_mem) : (In_cols * chans_per_mem);

	(* DONT_TOUCH = "yes" *) logic [ADDR_WIDTH-1:0] batch_offset;
	assign batch_offset = ((`batch_size - 1)* chans_per_mem);

////////////////////////////////////////////////STATES///////////////////////////////////////////////////////////////////
	(* DONT_TOUCH = "yes" *) logic [1:0] state;
	assign state_current = state; 											//for output	
	(* DONT_TOUCH = "yes" *) logic [1:0] next_state;

	(* DONT_TOUCH = "yes" *) logic [1:0] read_state;
	(* DONT_TOUCH = "yes" *) logic [1:0] next_read_state; 
	
////////////////////////////////////////////////CONTROL///////////////////////////////////////////////////////////////////
(* DONT_TOUCH = "yes" *) logic tn_first, tn_last, tk_first, tk_last, tm_first, tm_last, tl_first, tl_last, start_read, read_ready;

	always @(posedge clk) 
	begin
		if (ram_full) begin
			read_ready = 1; 
		end
	end
//horizontal_ctr and output_vericle_counter
	assign tn_first = ((row_ctr == 0) && (verical_ctr == 0) && (valid_read)); 
	assign tn_last = ((row_ctr == feed_row-1) && (verical_ctr == 2));
	assign tk_first = (batch_ctr == 0);
	assign tk_last = (batch_ctr == (`batch_size-1)) && tn_last;							
	assign tm_first = (kernel_reuse_ctr == 0);						
	assign tm_last = (kernel_reuse_ctr == TM-1) && tk_last;							
	assign lm_first = (lm_counter == 0); 												
	assign lm_last = (lm_counter == LM-1) && tm_last;
	assign start_read = (read_ready && valid_read);									 
	assign loop_ctrl = {tn_first, tn_last, tk_first, tk_last,
						tm_first, tm_last, lm_first, lm_last, start_read};


////////////////////////////////////////FSM state definition for writing////////////////////////////////////////
	always_comb //@ (state or rst or start or write_full or valid_write)
	begin : FSM_COMBO
 
		case (state)
			NO_USE		:	if (start && (!rst) && (!write_full) && valid_write) begin				// if start go into start 	
								wr_enable = 1;//FOR TESTING ONLY
								next_state = START;
							end else begin															//if start is 0 and reset is 0 stay in no use
								wr_enable = 0;
								next_state = NO_USE;
							end
			START		:	if(rst) begin
								next_state = NO_USE;
								wr_enable = 0;
							end else if ((!write_full) && valid_write) begin 						//if write is full, or if data not valid or if reset is true then go into idle  
								next_state = START;
								wr_enable = 0;								
							end else if (write_full) begin											//otherwise stay in start mode 
								wr_enable = 0;
								next_state = IDLE_WRITE;
							end else begin
								wr_enable = 0;
								next_state = START;
							end
			IDLE_WRITE 	:	if (rst) begin										//if reset then go to no_use 
								next_state = NO_USE;
								wr_enable = 0;
							end else if (!write_full) begin							// if writing is valid then go to reuse state gh
								wr_enable = (valid_write == 1) ? 1 : 0;
								next_state = REUSE_WRITE;
							end else if (write_full) begin
								next_state = IDLE_WRITE;
								wr_enable = 0;
							end else begin
								wr_enable = 0;
								next_state = IDLE_WRITE;
							end
			REUSE_WRITE :	if (rst) begin
								wr_enable = 0;
								next_state = NO_USE;
							end else if ((!write_full)) begin
								if (valid_write == 0) begin
									wr_enable = 0;
								end else begin
									wr_enable = 1;
								end
								next_state = REUSE_WRITE;
							end else if (write_full) begin
								wr_enable = 0;
								next_state = IDLE_WRITE;
							end else begin
								wr_enable = 0;
								next_state = REUSE_WRITE;
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
											row_index <= 0;
											row_reuse <= row_reuse;
										end else begin 
											row_index <= row_index + 1;
											row_reuse <= row_reuse;
										end
									end else begin
										row_index <= row_index;
										row_reuse <= row_reuse;
									end
								end

				START 		: 	if (row_index == (row_beg0 -1) && (padding == 1'b1)) begin
									row_index <= row_beg1;
								end else if (row_index == (row_beg3-1)) begin
									write_full <= 1;  									//write full goes to one when I've finished writing what i have intended to write. 
									row_index <= row_beg3;								//set write pointer to begining of the 4th row for reuse write 
									row_reuse <= 2; 										//2nd row is going to be reused for STRIDE-2!!!
									//valid_read <= 1;
									//read_index <= 0; 
								end else if (!write_full) begin
									row_index <= row_index + 1;
								end	
				NO_USE  	:	begin
									row_index <= (padding == 1) ? row_beg1 : 0;
									row_reuse <= 0;
									write_full <= 0; 
								end
				REUSE_WRITE : 	if (row_reuse == 0) begin
									if (row_index == (row_beg3 - 1)) begin
										write_full <= 1;
										row_index <= row_beg3;
										row_reuse <= 2;						
									end else if(row_index == (row_beg2-1)) begin
										write_full <= 1;
										row_index <= row_beg2;
									end else if(!write_full) begin
										row_index <= row_index + 1; 
									end
								end else begin
									if (row_index == (row_beg1 - 1)) begin
										write_full <= 1;
										row_index <= row_beg1;							//if fuck up in index writing change this
										row_reuse <= 0;
									end else if(row_index == last_idx) begin
										write_full <= 1;
										row_index <= row_beg0; 
									end else if (!write_full) begin
										row_index <= row_index + 1; 
									end
								end
			endcase
		end
	end

///*
////////////////////////////////////////FSM states and transition for reading////////////////////////////////////////
	always_comb //@ (valid_read or rst) //  @ (read_state)
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
							end else begin
								next_read_state = REUSE_READ;
							end
			default		:	begin
								next_read_state = IDLE_READ;
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
			horizontal_ctr <= 0;
			row_ctr <= 0;
			output_verical_ctr <= 0;
			read_index <= 0;
			horizontal_read_count <= 0;
			kernel_reuse_ctr <= 0;
			batch_ctr <= 0; 
			lm_counter <= 0;
			read_counter <= 0; 
		end else begin
			case(read_state)
				IDLE_READ	:	begin
										read_index <= read_index;
										verical_ctr <= verical_ctr;
										horizontal_ctr <= horizontal_ctr;
										output_verical_ctr <= output_verical_ctr;
										last_out <= 0;

								end

				REUSE_READ	:	if (output_verical_ctr < o_dimension) begin
									//if ((((horizontal_read_count == stride_write) || (horizontal_read_count == ((total_horizontal_read - read_row_beg) - 1))) && (write_full == 1) && (k_dimension != 1)) && (lm_counter == (LM-1))) begin
									//	write_full <= 0;
									//end else if ((((horizontal_read_count >= 0) && (horizontal_read_count < (read_row_beg * 2))) && (k_dimension == 1)) && (lm_counter == (LM-1))) begin
									//	write_full <= 0;
									//end
									if (row_ctr < (feed_row-1)) begin 										
										if (((output_verical_ctr == 0) && (verical_ctr == 0) && (padding == 1'b1)) || ((output_verical_ctr == (o_dimension-1)) && (verical_ctr == 2) && (padding == 1'b1) && (((In_cols%2) != 0) || (stride == 2'b01)))) begin
											//temp_read_index <= read_index;
											read_index <= 0;
										end else begin
											if ((horizontal_ctr == (horizontal_o_dimension-1)) && (row_ctr == ((feed_row-1)-chans_per_mem)) && (padding ==1'b1) && (((In_cols%2) != 0) || (stride == 2'b01))) begin
												temp_read_index <= read_index;
												read_index <= 0;
												padding_flag <= 1;
											end else begin
												read_index <= ((((row_ctr + 1) % (chans_per_mem)) == 0) && (`batch_size > 1)) ? ((read_index + batch_offset) + 1) : (read_index + 1);
												/*if (((row_ctr + 1) % (chans_per_mem)) == 0) begin
													if (k_dimension != 1) begin
														read_index <= ((read_index + batch_offset) + 1);
													end else if (k_dimension == 1) begin
														if ( kernel_reuse_counter < (TM-1)) begin 
															batch_ctr <= batch_ctr + 1; 
															if (batch_ctr < (`batch_size-1))
																batch_ctr <= batch_ctr + 1;
																read_index <= read_index + 1;  
															end else begin 
																batch_ctr <= 0; 
																kernel_reuse_counter <= kernel_reuse_counter + 1;
																read_index <= ((read_index - batch_offset) - (chans_per_mem - 1)); 
															end
														end else begin 
															batch_ctr <= 0; 
															kernel_reuse_counter <= 0; 
															read_index <= read_index + 1; 
														end

													end
												end else begin
													read_index <= read_index + 1; 
												end*/

												if ((row_ctr == chans_per_mem-1) && (horizontal_ctr == 0) && (padding_flag ==1) && (padding == 1'b1)) begin
													read_index <= temp_read_index+1;			//change this to remove the plus 1 by removing the (row_beg1-1) etc. from all the other vericle_ctr conditions
													padding_flag <= 0;
												end
											end
										end
										row_ctr <= row_ctr + 1; 
										horizontal_read_count <= horizontal_read_count + 1; 
									end else if (row_reuse == 2) begin
										if (verical_ctr == 0) begin
											if ((horizontal_ctr== 0) && (padding == 1'b1)) begin
												temp_read_index <= (stride_flag == 0) ? ((row_beg2-1) + (batch_ctr * chans_per_mem)) : ((row_beg1-1) + (batch_ctr * chans_per_mem));
												padding_flag <= 1;
												read_index <= 0;
											end else begin 
												if ((padding_flag == 1) && (padding == 1'b1)) begin
													if (output_verical_ctr == 0) begin
														read_index <= temp_read_index;
													end else begin
														read_index <= (temp_read_index + read_row_beg) - ((feed_row-1) - chans_per_mem) - (batch_offset * (k_dimension - 2));
													end
													padding_flag <= 0;
												end else begin
													read_index <= ((read_index + read_row_beg) - (feed_row-1)) - (batch_offset * (k_dimension - 1));
												end
											end
											row_ctr <= 0;
											verical_ctr <= verical_ctr + 1;
											horizontal_read_count <= horizontal_read_count + 1; 											
										end else if (verical_ctr == 1) begin
											if (((horizontal_ctr == 0) || ((output_verical_ctr == (o_dimension-1)) && (((In_cols%2) != 0) || (stride == 2'b01)))) && (padding == 1'b1)) begin
												if ((output_verical_ctr == (o_dimension-1))  && (((In_cols%2) != 0) || (stride == 2'b01))) begin
													temp_read_index <= (horizontal_ctr == (o_dimension-1)) ? temp_read_index : read_index;
												end else begin
													temp_read_index <= (stride_flag == 0) ? ((row_beg3-1) + (batch_ctr * chans_per_mem)):((row_beg2-1) + (batch_ctr * chans_per_mem));
												end
												padding_flag <= 1;
												read_index <= 0;
											end else begin
												if ((padding_flag == 1) && (padding == 1'b1)) begin
													read_index <= (temp_read_index + read_row_beg) - ((feed_row-1) - chans_per_mem) - (batch_offset * (k_dimension - 2));
													padding_flag <= 0;
												end else begin 
													read_index <= ((read_index + read_row_beg) - (feed_row-1)) - (batch_offset * (k_dimension - 1));			//add one row and subtract one feed row value 
												end
											end
											row_ctr <= 0;
											verical_ctr <= verical_ctr + 1;
											horizontal_read_count <= horizontal_read_count + 1;
										end else if (verical_ctr == 2) begin
											horizontal_ctr <= ((batch_ctr == (`batch_size - 1)) && (kernel_reuse_ctr == (TM-1))) ? (horizontal_ctr + 1) : (horizontal_ctr);
											if (kernel_reuse_ctr < (TM-1) && (batch_ctr == (`batch_size-1)) ) begin 
												kernel_reuse_ctr <= kernel_reuse_ctr + 1; 
												batch_ctr <= 0; 
												if ((output_verical_ctr == 0) || (horizontal_ctr == 0)) begin 
													read_index <= 0;
													temp_read_index <= prev_temp_read_index; 
													padding_flag <= 1; 
												end else begin 
													read_index <= prev_read_index;
													padding_flag <= 0; 
												end
												horizontal_read_count <= horizontal_read_count + 1; 
												verical_ctr <= 0;
												row_ctr <= 0;
											end else if (horizontal_ctr < (horizontal_o_dimension)) begin	
												kernel_reuse_ctr <= ((kernel_reuse_ctr == (TM-1)) && batch_ctr == (`batch_size-1)) ? 0 : kernel_reuse_ctr; 
												if (((output_verical_ctr == 0)) && (padding == 1'b1)) begin
													if (batch_ctr < (`batch_size-1)) begin
														batch_ctr <= batch_ctr + 1;
														temp_read_index <= (padding_flag == 1'b1) ? (((temp_read_index - (read_row_beg)) - (chans_per_mem-1)) - (batch_offset * (k_dimension - 2))) : (((read_index - (read_row_beg)) - ((feed_row-1) - chans_per_mem)) - (batch_offset * (k_dimension - 1)));
														//prev_temp_read_index <= (batch_ctr == 1) ? temp_read_index : prev_temp_read_index; 
													end else begin  
														batch_ctr <= 0; 
														temp_read_index <= (read_index) - (read_row_beg) - ((chans_per_mem * (stride_multiplier)) -1) - (batch_offset * stride_multiplier);
														prev_temp_read_index <= temp_read_index; 
													end
													read_index <= 0;
													padding_flag <= 1; 
												end else if ((output_verical_ctr == (o_dimension-1)) && (padding == 1'b1) && (padding_flag == 1)) begin
													if (batch_ctr < (`batch_size-1)) begin
														batch_ctr <= batch_ctr + 1; 
														if (horizontal_ctr == 0) begin
															read_index <= 0; 
															temp_read_index <= ((temp_read_index - (read_row_beg)) - chans_per_mem) - (batch_offset * (k_dimension - 2));
															//prev_temp_read_index <= (batch_ctr == 1) ? temp_read_index : prev_temp_read_index; 
														end else begin 
															read_index <= (horizontal_ctr == (o_dimension-1)) ? ((((temp_read_index - (read_row_beg)) - (chans_per_mem-1)) - (batch_offset * (k_dimension - 2)))) : ((((temp_read_index - (read_row_beg)) - ((feed_row-1) - chans_per_mem)) - (batch_offset * (k_dimension - 1)))); 
															//prev_read_index <= (batch_ctr == 1) ? read_index : prev_read_index;
														end	
													end else begin
														batch_ctr <= 0; 
														read_index <= temp_read_index - (read_row_beg) - ((chans_per_mem * (stride_multiplier)) -1) - (batch_offset * stride_multiplier);
														prev_read_index <= read_index; 
													end
													padding_flag <= (horizontal_ctr == 0) ? 1 : 0;
												end else begin 
													if (batch_ctr < (`batch_size-1)) begin
														batch_ctr <= batch_ctr + 1;
														if (horizontal_ctr == 0) begin 
															temp_read_index <= (((read_index - (read_row_beg + read_row_beg)) - (chans_per_mem)) - (batch_offset * (k_dimension - 2)));
															//prev_temp_read_index <= (batch_ctr == 1) ? temp_read_index : prev_temp_read_index; 
															read_index <= 0;
															padding_flag <= 1;
														end else begin
															read_index <= (padding_flag == 1) ? (((temp_read_index - (read_row_beg + read_row_beg)) -  (chans_per_mem-1)) - (batch_offset * (k_dimension - 2))) : ((((read_index - (read_row_beg + read_row_beg)) - ((feed_row-1) - chans_per_mem)) - (batch_offset * (k_dimension - 1))));
															//prev_read_index <= (batch_ctr == 1) ? read_index : prev_read_index;
														end
													end else begin  
														batch_ctr <= 0; 
														read_index <= (read_index) - (read_row_beg + read_row_beg) - ((chans_per_mem * (stride_multiplier)) -1) - (batch_offset * stride_multiplier);
														prev_read_index <= read_index; 
													end
												end
												verical_ctr <= 0;
												row_ctr <= 0;
												horizontal_read_count <= horizontal_read_count + 1;
											end else if ((stride == 2'b01) && (((lm_counter == (LM-1)) && stride_flag) || ((lm_counter < (LM-1)) && !(stride_flag)))) begin
												if (padding == 1'b1) begin
													temp_read_index <= row_beg1-1;
													prev_temp_read_index <= temp_read_index; 
													read_index <= 0;
													padding_flag <= 1;
												end else begin
													read_index <= row_beg1;
													prev_read_index <= (batch_ctr == 1) ? read_index : prev_read_index;
												end
												if (lm_counter < (LM-1)) begin
													lm_counter <= lm_counter + 1; 
													//,stride_flag <= 1; 
												end else begin
													lm_counter <= 0; 
													stride_flag <= 0; 
													output_verical_ctr <= output_verical_ctr + 1; 
												end
												horizontal_ctr <= 0;
												read_counter <= read_counter + horizontal_read_count;
												horizontal_read_count <= 0;
												row_ctr <= 0;
												verical_ctr <= 0;
												batch_ctr <= 0; 
												kernel_reuse_ctr <= 0; 
											end else begin
												if (padding == 1'b1) begin
													temp_read_index <= row_beg0-1;
													prev_temp_read_index <= temp_read_index; 
													read_index <= 0;
													padding_flag <= 1;
												end else begin 
													read_index <= (k_dimension != 1) ? (row_beg0) : (row_beg3);
													prev_read_index <= read_index; 
												end
												if (lm_counter < (LM-1)) begin
													lm_counter <= lm_counter + 1; 
													//stride_flag <= 1; 
												end else begin
													lm_counter <= 0; 
													stride_flag <= 1; 
													output_verical_ctr <= output_verical_ctr + 1; 
												end
												horizontal_ctr <= 0;
												read_counter <= read_counter + horizontal_read_count;
												horizontal_read_count <= 0;
												row_ctr <= 0;
												verical_ctr <= (k_dimension != 1) ? (0) : (1);
												batch_ctr <= 0;  
												kernel_reuse_ctr <= 0; 
											end
										end
									end else if (row_reuse == 0) begin
										if (verical_ctr == 0) begin
											if (stride_flag == 0) begin
												if ((horizontal_ctr == 0) && (padding == 1'b1)) begin
													temp_read_index <= (row_beg0 -1) +  (batch_ctr * chans_per_mem);
													read_index <= 0;
													padding_flag <= 1;
												end else begin
													if ((padding_flag == 1) && (padding == 1'b1)) begin
														read_index <= (temp_read_index - (read_row_beg + read_row_beg + read_row_beg)) - ((feed_row-1)-chans_per_mem) - (batch_offset * (k_dimension - 2));
														padding_flag <= 0;
													end else begin
														read_index <= (((read_index - (read_row_beg + read_row_beg + read_row_beg)) - (feed_row-1)) )- (batch_offset * (k_dimension - 1));
													end
												end
											end else begin
												if ((horizontal_ctr == 0) && (padding == 1'b1)) begin
													temp_read_index <= (row_beg3 -1) + (batch_ctr * chans_per_mem); 
													read_index <= 0;
													padding_flag <= 1;
												end else begin 
													if ((padding_flag == 1) && (padding == 1'b1)) begin
														read_index <= (temp_read_index + read_row_beg) - ((feed_row-1) - chans_per_mem) - (batch_offset * (k_dimension - 2));
														padding_flag <= 0;
													end else begin 
														read_index <= ((read_index + read_row_beg) - (feed_row-1)) - (batch_offset * (k_dimension - 1));
													end
												end
											end
											row_ctr <= 0;
											verical_ctr <= verical_ctr + 1;
											horizontal_read_count <= horizontal_read_count + 1;
										end else if (verical_ctr == 1) begin
											if (stride_flag == 0) begin
												if (((horizontal_ctr == 0) || ((output_verical_ctr == (o_dimension-1)) && (((In_cols%2) != 0) || (stride == 2'b01)))) && (padding == 1'b1)) begin
													if ((output_verical_ctr == (o_dimension-1)) && (((In_cols%2) != 0) || (stride == 2'b01))) begin
														temp_read_index <= (horizontal_ctr == o_dimension-1) ? temp_read_index : read_index;
													end else begin 
														temp_read_index <= (row_beg1 - 1) + (batch_ctr * chans_per_mem);
													end
													read_index <= 0;
													padding_flag <= 1;
												end else begin
													if((padding_flag ==1) && (padding == 1'b1)) begin
														read_index <= ((temp_read_index + read_row_beg) - ((feed_row-1)-chans_per_mem)) - (batch_offset * (k_dimension - 2));
														padding_flag <= 0;
													end else begin
														read_index <= ((read_index + read_row_beg) - (feed_row-1) - (batch_offset * (k_dimension - 1)));
													end 
												end
											end else begin
												if (((horizontal_ctr == 0) || ((output_verical_ctr == (o_dimension-1)) && (((In_cols%2) != 0) || (stride == 2'b01)))) && (padding == 1'b1)) begin
													if ((output_verical_ctr == o_dimension-1) && ((In_cols % 2) != 0)) begin
														temp_read_index <= (horizontal_ctr == (o_dimension-1)) ? temp_read_index : read_index;
													end else begin
														temp_read_index <= (row_beg0 -1) + (batch_ctr * chans_per_mem);
													end	
													read_index <= 0;
													padding_flag <= 1;
												end else begin 
													if ((padding_flag == 1) && (padding == 1'b1)) begin
														read_index <= (temp_read_index - (read_row_beg + read_row_beg + read_row_beg) - ((feed_row-1) - chans_per_mem)) - (batch_offset * (k_dimension - 2));
														padding_flag <= 0;
													end else begin 
														read_index <= ((read_index - (read_row_beg + read_row_beg + read_row_beg)) - (feed_row-1)) - (batch_offset * (k_dimension - 1));
													end
												end
											end
											row_ctr <= 0;
											verical_ctr <= verical_ctr + 1;
											horizontal_read_count <= horizontal_read_count + 1;
										end else if (verical_ctr == 2) begin
											horizontal_ctr <= ((batch_ctr == (`batch_size - 1) ) && (kernel_reuse_ctr == (TM-1))) ? (horizontal_ctr + 1) : (horizontal_ctr);
											if ((kernel_reuse_ctr < (TM-1)) && (batch_ctr == (`batch_size-1))) begin 
												kernel_reuse_ctr <= kernel_reuse_ctr + 1; 
												batch_ctr <= 0; 
												if ((horizontal_ctr == 0)) begin 
													read_index <= 0;
													temp_read_index <= prev_temp_read_index; 
													padding_flag <= 1; 
												end else begin 
													read_index <= prev_read_index;
													padding_flag <= 0; 
												end
												horizontal_read_count <= horizontal_read_count + 1; 
												verical_ctr <= 0;
												row_ctr <= 0;
											end else if (horizontal_ctr < horizontal_o_dimension) begin
												kernel_reuse_ctr <= ((kernel_reuse_ctr == (TM-1)) && batch_ctr == (`batch_size-1)) ? 0 : kernel_reuse_ctr; 
												if (stride_flag == 1) begin
													if ((output_verical_ctr == (o_dimension-1)) && (padding == 1'b1) && (padding_flag == 1)) begin
														if (batch_ctr < (`batch_size-1)) begin
															batch_ctr <= batch_ctr + 1; 
															if (horizontal_ctr == 0) begin
																read_index <= 0;
																temp_read_index <= (((temp_read_index - (read_row_beg) - (chans_per_mem)) - (batch_offset * (k_dimension - 2))));
																//prev_temp_read_index <= temp_read_index;
															end else begin  
																read_index <= (horizontal_ctr == (o_dimension-1)) ? ((((temp_read_index - (read_row_beg)) - (chans_per_mem-1)) - (batch_offset * (k_dimension - 2)))) : ((((temp_read_index - (read_row_beg)) - ((feed_row-1) - chans_per_mem)) - (batch_offset * (k_dimension - 1))));
																//prev_read_index <= read_index; 
															end
														end else begin 
															batch_ctr <= 0; 
															read_index <= ((temp_read_index - (read_row_beg)) - ((chans_per_mem * (stride_multiplier)) -1)) - (batch_offset * stride_multiplier);
															prev_read_index <= read_index; 
															//read_index <= 0;
														end	
														padding_flag <= (horizontal_ctr == 0) ? 1 : 0;
													end else begin
														if (batch_ctr < (`batch_size-1)) begin
															batch_ctr <= batch_ctr + 1;
															if (horizontal_ctr == 0) begin 
																temp_read_index <= (((read_index + (read_row_beg + read_row_beg)) - (chans_per_mem)) - (batch_offset * (k_dimension - 2)));
																//prev_temp_read_index <= temp_read_index;
																read_index <= 0;
																padding_flag <= 1;
															end else begin 
																read_index <= (padding_flag == 1) ? (((temp_read_index + (read_row_beg + read_row_beg))  -  (chans_per_mem-1)) - (batch_offset * (k_dimension - 2))) : ((read_index + (read_row_beg + read_row_beg)) - ((feed_row-1) - chans_per_mem)) - (batch_offset * (k_dimension - 1));
																//prev_read_index <= read_index;
															end
														end else begin
															batch_ctr <= 0;
															read_index <= ((read_index + (read_row_beg + read_row_beg)) - ((chans_per_mem * (stride_multiplier)) -1)) - (batch_offset * stride_multiplier);
															prev_read_index <= read_index;
														end
													end
													verical_ctr <= 0;
													row_ctr <= 0;
													horizontal_read_count <= horizontal_read_count + 1;
												end else if (stride_flag == 0) begin
													if ((output_verical_ctr == (o_dimension-1)) && (padding == 1'b1) && (padding_flag == 1)) begin
														if (batch_ctr < (`batch_size-1)) begin
															batch_ctr <= batch_ctr + 1; 
															if (horizontal_ctr == 0) begin
																read_index <= 0;
																temp_read_index <= (((temp_read_index + (read_row_beg *3) - (chans_per_mem)) - (batch_offset * (k_dimension - 2))));
																//prev_temp_read_index <= temp_read_index;
															end else begin  
																read_index <= (horizontal_ctr == (o_dimension-1)) ? ((((temp_read_index + (read_row_beg*3)) - (chans_per_mem-1)) - (batch_offset * (k_dimension - 2)))) : ((((temp_read_index + (read_row_beg*3)) - ((feed_row-1) - chans_per_mem)) - (batch_offset * (k_dimension - 1))));
																//prev_read_index <= read_index;
															end
														end else begin 
															batch_ctr <= 0; 
															read_index <= ((temp_read_index + (read_row_beg*3)) - ((chans_per_mem * (stride_multiplier)) -1)) - (batch_offset * stride_multiplier);
															prev_read_index <= read_index;
														end	
														padding_flag <= (horizontal_ctr == 0) ? 1 : 0;
													end else begin 
														if (batch_ctr < (`batch_size-1)) begin
															batch_ctr <= batch_ctr + 1;
															if (horizontal_ctr == 0) begin 
																temp_read_index <= (((read_index + (read_row_beg + read_row_beg))- (chans_per_mem)) - (batch_offset * (k_dimension - 2)));
																//prev_temp_read_index <= temp_read_index;
																read_index <= 0;
																padding_flag <= 1; 
															end else begin 
																read_index <= (horizontal_ctr == (o_dimension-1)) ? (((temp_read_index + (read_row_beg + read_row_beg)) - (chans_per_mem-1)) - (batch_offset * (k_dimension - 2))) : ((read_index + (read_row_beg + read_row_beg)) - ((feed_row-1) - chans_per_mem)) - (batch_offset * (k_dimension - 1));
																//prev_read_index <= read_index;
																padding_flag <= (horizontal_ctr == 0) ? 1 : 0; 
															end
														end else begin
															batch_ctr <= 0;
															read_index <= ((read_index + (read_row_beg + read_row_beg)) - ((chans_per_mem * (stride_multiplier)) -1)) - (batch_offset * stride_multiplier);
															prev_read_index <= read_index;
														end
													end
													verical_ctr <= 0;
													row_ctr <= 0;
													horizontal_read_count <= horizontal_read_count + 1;
												end
											end else if ((stride == 2'b01) && (((lm_counter == (LM-1)) && stride_flag) || ((lm_counter < (LM-1)) && !(stride_flag)))) begin
												if(padding == 1'b1) begin
													temp_read_index <= row_beg3-1;
													prev_temp_read_index <= temp_read_index; 
													read_index <= 0;
													padding_flag <= 1;
												end else begin
													read_index <= row_beg3;
													prev_read_index <= read_index; 
												end
												if (lm_counter < (LM-1)) begin
													lm_counter <= lm_counter + 1; 
													//,stride_flag <= 1; 
												end else begin
													lm_counter <= 0; 
													stride_flag <= 0; 
													output_verical_ctr <= output_verical_ctr + 1; 
												end
												horizontal_ctr <= 0;
												read_counter <= read_counter + horizontal_read_count;
												horizontal_read_count <= 0;
												row_ctr <= 0;
												verical_ctr <= 0;
												batch_ctr <= 0; 
												kernel_reuse_ctr <= 0;  
											end else begin
												if(padding == 1'b1) begin
												 	temp_read_index <= row_beg2-1;
												 	prev_temp_read_index <= temp_read_index; 
													read_index <= 0;
													padding_flag <= 1;
												end else begin
													if (k_dimension == 1) begin
														read_index <= (output_verical_ctr == 0) ? (row_beg3) : (row_beg1);
													end else begin
														read_index <= row_beg2;
														prev_read_index <= read_index; 
													end
												end
												if (lm_counter < (LM-1)) begin
													lm_counter <= lm_counter + 1; 
													//stride_flag <= 1; 
												end else begin
													lm_counter <= 0; 
													stride_flag <= 1; 
													output_verical_ctr <= output_verical_ctr + 1; 
												end
												horizontal_ctr <= 0;
												read_counter <= read_counter + horizontal_read_count;
												horizontal_read_count <= 0;
												row_ctr <= 0;
												verical_ctr <= (k_dimension != 1) ? (0) : (1);
												batch_ctr <= 0;  
												kernel_reuse_ctr <= 0;  										
											end
										end
									end
								end else begin
									last_out <= 1;
									output_verical_ctr <= 0;
									read_index <= 0;
									row_ctr <= 0;
									horizontal_ctr <= 0;
									horizontal_read_count <= 0;
									read_counter <= 0;
									verical_ctr <= 0;
									batch_ctr <= 0;
									kernel_reuse_ctr <= 0; 
									lm_counter <= 0; 
								end

				default :		begin
									read_index <= read_index;
									verical_ctr <= verical_ctr;
									horizontal_ctr <= horizontal_ctr;
									output_verical_ctr <= output_verical_ctr;
									last_out <= 0;
								end

			endcase
		end
	end
//*/

////////////////////////////////////////Connections to dual port RAM////////////////////////////////////////
(* DONT_TOUCH = "yes" *) sync_dp_ram #(DATA_WIDTH, ADDR_WIDTH) mem ( 
	.data_a(data_in), 
	.data_b(),
	.addr_a(row_index), 
	.addr_b(read_index),
	.we_a(wr_enable), 
	.we_b(), 
	.clk(clk),
	.q_a(), 	
	.q_b(buffer_data_out_0)
);

(* DONT_TOUCH = "yes" *) logic [`B_WIDTH-1:0] buffer_data_out_1 [0:M-1];

genvar i;
	generate
		for (i=0; i<M; i++) begin
			assign buffer_data_out_1[i] = buffer_data_out_0[(i+1)*`B_WIDTH -1:i*`B_WIDTH];
		end
	endgenerate

	// wavefront out
	wavefront_multi #(`B_WIDTH, M) wave_feeder(clk, buffer_data_out_1, data_out);

endmodule : feeder
