`include "dp_ram.sv"
`include "feeder.sv"
`include "defs.sv"
//`include "defs.sv"


module in_ram_write_tb;
  parameter DATA_WIDTH = 16;
  parameter ADDR_WIDTH = 16;
  parameter TOTAL_WRITE = `In_rows * `In_cols * `chans_per_mem; 
  parameter READ_LAST = `K_cols * `K_rows * `chans_per_mem * `o_dimension * `o_dimension;
  // clock declaration
  logic clk = 0;
  logic rst = 0;

  // clock generation
  always #1 clk++;

  logic [DATA_WIDTH-1: 0] data_in;
  logic [ADDR_WIDTH-1: 0] addr;
  logic valid_write, start;
  wire [DATA_WIDTH-1: 0] data_out;   
  logic[ADDR_WIDTH -1 : 0] counter; 
  logic[1:0 ] state ;
  logic wr_check;
  reg [DATA_WIDTH-1:0] feeder [TOTAL_WRITE-1:0];
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
  integer fp;
  logic [ADDR_WIDTH-1:0] rd_idx;


  feeder fed( clk,          //clock transition for fsm 
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
    o_dimension
    );


  // test generation
  initial begin

    // dump files
    $dumpfile("dump.vcd"); 
    $dumpvars;
    $display("loading feeder");
    $readmemh("myfile2.txt", feeder);
    fp = $fopen($sformatf("OUTPUT.txt"));

    stride = 2'b10;
    chans_per_mem = 64;
    In_cols = 5;
    k_dimension = 3;
    o_dimension = 2;
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
      if (!last_out) begin
        data_in = feeder[i];
        i = i+1;
      end else begin
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
    if (start_read && j < (READ_LAST+2)) begin
      if (j>1) begin
        //if (((j-2)%9) == 0) begin
         // $fwrite(fp, "\n%0d ", data_out);
         // j = j+1;
        //end else begin
          $fwrite(fp, "%0d ", data_out);
          j = j+1;
        //end
      end else begin
        j = j+1; 
      end
    end else if (j == (READ_LAST+2)) begin
      $finish;
    end
  end
endmodule

    /*
    if (!ram_full && start) begin
      valid_write = 1;
    end else begin
      valid_write = 0;
    end
  end

  always @(posedge clk)
  begin
    if (!ram_full && valid_write) begin
      if (i < 75) begin
        data_in = feeder[i];
        i = i+1;
      end else begin 
        i = 0; 
      end
    end 
  end
endmodule : in_ram_write_tb
 */


  /*  // write to port A
    for (int i=0; i<75; i++) begin
      @(posedge clk)
      if (!ram_full) begin
        valid_write <= 1;
        data_in <= feeder[i];
      end else begin
        valid_write <= 0;
      end
    end

    #10 $finish;

  end


endmodule

*/
