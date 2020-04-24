//`include "dp_ram.sv"
`include "feeder.sv"
`include "defs.sv"
//`include "defs.sv"


module in_ram_write_tb;

  parameter DATA_WIDTH = 8;
  parameter ADDR_WIDTH = 16;
  //CHANGE HERE -->
  parameter TOTAL_WRITE = (`In_rows * `In_cols * (`chans_per_mem/`stream_width)* `batch_size); 
  parameter READ_LAST = (`K_cols * `K_rows * (`chans_per_mem/`stream_width) * `o_dimension * `o_dimension) * `batch_size;
  parameter M =1; 
  parameter N =1; 

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


  feeder #(1,1) fed ( clk,          //clock transition for fsm 
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

    stride = 2'b01;
    //AND HERE -->
    chans_per_mem = (1/`stream_width);

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
      $finish;
    end
  end
endmodule
