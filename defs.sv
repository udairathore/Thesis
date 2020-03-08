// -------------------------------
// Include file
// -------------------------------

// 1. Padded - Matrix Dimensions
`define In_rows			5		//TAKE INTO ACCOUNT PADDING!!! --> DONT BE DUMB AGAIN! 
`define In_cols			5
`define K_rows			3
`define K_cols			3
`define chans			64
`define chans_per_mem	64 		
//`define stride 			1
`define padding 		1
//`define o_dimension		((`In_rows + (2 * `padding) - `K_rows)/`stride) + 1	
`define o_dimension 	2	


// 2. Systolic Array dimensions
`define M_ARR 2
`define N_ARR 2

// 3. Data path params
`define A_WIDTH 	8
`define B_WIDTH 	8
`define C_WIDTH 	32
`define CTRL_WIDTH 	4

// 4. PE computation
`define A_WORDS 	1
`define B_WORDS 	1
`define C_WORDS 	1

// 5. Feeder A
`define A_WORDS_PER_BEAT 	2
`define A_STREAM_WIDTH 		`A_WIDTH*`A_WORDS_PER_BEAT

// 6. Feeder B
`define B_WORDS_PER_BEAT 	2
`define B_STREAM_WIDTH 		`B_WIDTH*`B_WORDS_PER_BEAT

// 7. Drain C
`define C_WORDS_PER_BEAT 	2
`define C_STREAM_WIDTH 		`C_WIDTH*`C_WORDS_PER_BEAT

// 8. RAM params
`define RAM_DEPTH_ROWS  4      // Number of rows that can fit into the memory --> Algorithm for now only works with 4 rows. 
`define RAM_PIPE 		1
`define RAM_READ_PE 	1
`define RAM_WRITE_PE 	2
`define RAM_READ_FD 	1
`define RAM_WRITE_FD 	2

// 9. CTRL Params
`define FEEDER_CTRL_LOOP_INNER 0 
`define FEEDER_CTRL_LOOP_OUTER 3

// 10. path directory to data
//`define DATA_PATH "/home/sean/projects/fast_mm/src/test/data"
//`define DATA_PATH "/home/sean/brown/src/test/data"

