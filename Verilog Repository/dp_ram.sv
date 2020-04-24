`include "defs.sv"

module sync_dp_ram  #(DATA_WIDTH=16, ADDR_WIDTH=8, MEM_INIT="C:/Users/Admin/Desktop/Verilog Projects/Memory_Data/zero.mem") (
	data_a, 
	data_b,
	addr_a, 
	addr_b,
	we_a, 
	we_b, 
	clk,
    // input rst --> how to implement a reset without a for loop??
	q_a, 	
	q_b
);

	//parameter DATA_WIDTH = 16;
	//parameter ADDR_WIDTH = 16;
	parameter TOTAL_SPACE = (((`In_rows * (`chans_per_mem/`stream_width) * `RAM_DEPTH_ROWS)+(`chans_per_mem/`stream_width))*`batch_size);
	parameter RAM_DEPTH = TOTAL_SPACE ;
	

	input [DATA_WIDTH - 1 : 0] data_a, data_b;
	input [ADDR_WIDTH - 1 : 0] addr_a, addr_b;
	input we_a, we_b, clk;
    // input rst --> how to implement a reset without a for loop??
	output reg [DATA_WIDTH - 1 : 0] q_a, q_b;


	// Declare the RAM variable
	reg [DATA_WIDTH - 1 :0] ram[RAM_DEPTH - 1 : 0];	

	initial begin
		for (int i=0; i<RAM_DEPTH; i++) begin
			ram[i] = 0;
		end
	end

	initial begin
	   	$readmemh(MEM_INIT, ram);
	end

	// Port A
 	always @ (posedge clk)
	begin
		if (we_a) 
		begin
			ram[addr_a] <= data_a;
			q_a <= data_a;
		end
		else 
		begin
			q_a <= ram[addr_a];
		end
	end
	
	// Port B
	always @ (posedge clk)
	begin
		if (we_b)
		begin
			ram[addr_b] <= data_b;
			q_b <= data_b;
		end
		else
		begin
			q_b <= ram[addr_b];
		end
	end
	
endmodule

