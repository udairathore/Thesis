`include "systolic_array.sv"
`include "utils.sv"
`include "defs.sv"
`include "feeder.sv"

module systolic_tb;

  // must match "make_mem.py" arguments
  parameter B_ROWS = 4;
  parameter B_COLS = 4;
  parameter WORDS_PER_PACKET = 2;
  parameter PACKET_SIZE = `B_WIDTH*WORDS_PER_PACKET;
  parameter NUM_PACKETS = (B_ROWS*B_COLS/WORDS_PER_PACKET);
  parameter M_DIM = 2;
  parameter N_DIM = 1;
  parameter DATA_WIDTH = 8;
  parameter ADDR_WIDTH = 16;
  //CHANGE HERE -->
  parameter TOTAL_WRITE = (`In_rows * `In_cols * (`chans_per_mem/`stream_width)* `batch_size); 
  parameter READ_LAST = (`K_cols * `K_rows * (`chans_per_mem/`stream_width) * `o_dimension * `o_dimension) * `batch_size;
  parameter M = M_DIM; 
  parameter N = N_DIM; 

  // clock declaration
  logic clk = 0;
  logic rst = 0;

  // clock generation
  always #1 clk++;

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
  logic last_out; 
  integer i = 0;
  integer j = 0; 
  integer k = 0;
  integer x = 0;
  integer fp;
  logic [ADDR_WIDTH-1:0] rd_idx;
  integer total_write = 0;
  logic [7:0] loop_ctrl;


  feeder #(M,N) fed ( clk,          //clock transition for fsm 
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


  initial begin
    $display("loading feeders");
    $readmemh("myfile3.txt", feeder);
  end

  logic [(DATA_WIDTH * `stream_width)-1: 0] tempB = 0;

  genvar u;
  for (u=0; u<`stream_width; u++) begin
    assign data_in[(u+1)*`B_WIDTH -1:u*`B_WIDTH] = tempB[(`stream_width-u)*`B_WIDTH -1:(`stream_width-u-1)*`B_WIDTH];
  end

  initial begin
    $display("Packet Size: %0d bits (%0d x %0d-bit words per packet)", PACKET_SIZE, WORDS_PER_PACKET, `B_WIDTH);
    $display("Array Dimensions: %0dx%0d", M_DIM, N_DIM);
    $display("Stream B Dimensions: %0dx%0d", B_ROWS, B_COLS);
  end


  logic [`CTRL_WIDTH-1:0] wave_ctrl [0:M];
  logic [`B_WIDTH-1: 0] inputs [M_DIM];
  logic [`B_WIDTH-1: 0] wave_inputs [M_DIM];  
  logic [32-1:0] psum [N_DIM];

  // design under test
  //wavefront_multi #(`OPWIDTH, M_DIM) iact_feeder(clk, inputs, wave_inputs);
  systolic #(M,N) array (clk, rst, loop_ctrl, data_out, psum);


  // two input matrices (zero padding for wavefront)
//  logic [PACKET_SIZE-1:0] feeder [0:NUM_PACKETS-1];

  reg [PACKET_SIZE-1:0] temp;


  // assign input channels
/*  genvar i;
  generate
    for(i=0; i<M_DIM; i=i+1) begin : b1
      assign inputs[i] = temp[(M_DIM-1-i)*`OPWIDTH +: `OPWIDTH];
    end
  endgenerate
*/

  // test generation
  initial begin

    // dump files
    $dumpfile("dump.vcd"); 
    $dumpvars;

    // init reset
    fp = $fopen($sformatf("OUTPUT.txt"));

    stride = 2'b01;
    //AND HERE -->
    chans_per_mem = (4/`stream_width);

    In_cols = 3;
    k_dimension = 3;
    o_dimension = 3;
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
        //if (x<(chans_per_mem)) begin
        //  tempB = 0;
        //  x = x+1;
       // end else begin
          tempB = feeder[i];
          i = i+1;
       // end
      end else begin
       #1
        valid_write <= 0;
      end
    end else if (ram_full) begin
      //valid_write = 0;
      start_read = 1;
     // #2;
    end
  end
  always @(posedge clk) 
  begin
    if (start_read && !(last_out)) begin
      if (j>1) begin
        //if (((j-2)%9) == 0) begin
         // $fwrite(fp, "\n%0d ", data_out);
         // j = j+1;
        //end else begin
          $fwrite(fp, "%0p ", data_out);
          j = j+1;
        //end
      end else begin
        j = j+1; 
      end
    end else if (last_out) begin
      $finish;
    end
  end
endmodule
