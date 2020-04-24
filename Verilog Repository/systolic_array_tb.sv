`timescale 1 ns/10 ps

`include "systolic_array.sv"
`include "defs.sv"
`include "feeder.sv"

module systolic_tb_v2;

  // must match "make_mem.py" arguments
  //parameter B_ROWS = 4;
  //parameter B_COLS = 4;
  //parameter WORDS_PER_PACKET = 2;
  //parameter PACKET_SIZE = `OPWIDTH*WORDS_PER_PACKET;
  //parameter NUM_PACKETS = (B_ROWS*B_COLS/WORDS_PER_PACKET);
  //parameter M_DIM = `M_ARR;
  //parameter N_DIM = `N_ARR;
  parameter DATA_WIDTH = 8;
  parameter ADDR_WIDTH = 16;
  parameter M = `M_ARR; 
  parameter N = `N_ARR; 
  parameter TOTAL_WRITE = (`In_rows * `In_cols * (`chans_per_mem/`stream_width)* `batch_size); 


 /* initial begin
    $display("Packet Size: %0d bits (%0d x %0d-bit words per packet)", PACKET_SIZE, WORDS_PER_PACKET, `OPWIDTH);
    $display("Array Dimensions: %0dx%0d", M_DIM, N_DIM);
    $display("Stream B Dimensions: %0dx%0d", B_ROWS, B_COLS);
  end*/

  // clock declaration
  logic clk = 0;
  logic rst = 0;

  // clock generation
  always #2 clk++;


  //CHANGE HERE -->


  ///////////FEEDER PORTS//////////////
  logic [(DATA_WIDTH*`stream_width)-1: 0] data_in;
  logic [ADDR_WIDTH-1: 0] addr;
  logic valid_write, start;
  logic [`B_WIDTH -1:0] data_out [0:M-1];   
  logic[ADDR_WIDTH -1 : 0] counter; 
  logic[1:0 ] state ;
  logic wr_check;
  logic [(DATA_WIDTH * `stream_width)-1:0] feeder [TOTAL_WRITE-1:0];
  logic [7:0] last; 
  logic ram_full;
  logic start_read = 0;
  ///////////FEEDER PARAMETERS//////////////
  logic [1:0] stride;
  logic [ADDR_WIDTH-1:0] chans_per_mem;
  logic [ADDR_WIDTH-1:0] In_cols;
  logic [ADDR_WIDTH-1:0] o_dimension;
  logic [ADDR_WIDTH-1:0] k_dimension;
  logic [ADDR_WIDTH-1:0] rd_idx;
  integer total_write = 0;
  logic [8:0] loop_ctrl;
  logic last_out; 
  integer i = 0;
  integer j = 0; 
  integer fp;


  feeder #(M, N) fed ( clk,          //clock transition for fsm 
    rst,          //used to reset the whole fsm
    valid_write,      //determines when to write and when not to write --> probably based on write full??
    start,          //probably use it to determine when is the first time you are writing after reset, does not change once started
    data_in,
    //wr_pointer,       //goes to ram for determining which place to write to
    //wr_enable,        //enable writing to ram
    data_out,
    counter,
    state,
    wr_check,
    last,
    ram_full,
    rd_idx,
    stride,
    chans_per_mem,
    In_cols,
    last_out,
    k_dimension,
    o_dimension,
    loop_ctrl
    );


  //weight NOC
  logic wctrl [0:N-1][0:M-1];
  genvar l, k; 
    for (k =0; k<M; k=k+1) begin
      for (l=0; l<N; l=l+1) begin
        assign wctrl[l][k] = 1'b0;         
      end
    end

  logic [`C_WIDTH-1:0] psum [N];
  logic valid_pe_output [0:N-1];
  // design under test
  systolic #(M, N) array (
    .clk(clk), 
    .rst(rst), 
    .ctrl(loop_ctrl), 
    .iact(data_out), 
    .psum(psum),
    .wctrl(wctrl),
    .valid_out(valid_pe_output)
    );



  //LOAD FEEDER AND ASSIGN DATA IN CORRECTLY
  initial begin
    $display("loading feeders");
    $readmemh($sformatf(`DATA_PATH, "Bmem_no_batch.txt"), feeder);
  end

  logic [(DATA_WIDTH * `stream_width)-1: 0] tempB = 0;
  genvar u;
  for (u=0; u<`stream_width; u++) begin
    assign data_in[(u+1)*`B_WIDTH -1:u*`B_WIDTH] = tempB[(`stream_width-u)*`B_WIDTH -1:(`stream_width-u-1)*`B_WIDTH];
  end


 // test generation
  initial begin

    // dump files
    $dumpfile("dump.vcd"); 
    $dumpvars;
    fp = $fopen($sformatf("OUTPUT.txt"));

    stride = 2'b10;
    chans_per_mem = (`chans_per_mem/`stream_width);
    In_cols = `In_cols;
    k_dimension = `K_rows;
    o_dimension = `o_dimension;
    total_write = (In_cols * In_cols * chans_per_mem)*`batch_size; 
    rst <= 0;
    start <= 0;
    #10
    rst <= 1;
    repeat (20) @(posedge clk);
    rst <= 0;
    repeat (10) @(posedge clk);
    start <= 1;
    valid_write <= 1;
  end

  always @(posedge clk)
  begin
    if (!ram_full && start) begin
      if (i < total_write) begin
          tempB = feeder[i];
          i = i+1;
      end else begin
       #1
        valid_write <= 0;
      end
    end else if (ram_full) begin
      start_read = 1;
    end
  end

  always @(posedge clk) 
  begin
    if (start_read && !(last_out)) begin
      if (j>1) begin
          $fwrite(fp, "%0p ", data_out);
          j = j+1;
      end else begin
        j = j+1; 
      end
    end else if (last_out) begin
      start_read = 0; 
    end
  end

  always @(posedge clk)
  begin
    if ((start_read == 0) && (valid_pe_output[0])) begin
      $finish;
    end
  end
endmodule