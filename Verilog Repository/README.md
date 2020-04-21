This is the verilog repository for the CNN accelerator for training. 

1. defs.sv --> Consists of the relevant definitions required to run the simulation
2. dp_ram.sv --> Dual port Synchronus ram implementation in verilog. 
3. feeder.sv --> Convolution based feeder or windowing algorithm, which picks the relevant patches on which the dot product is to be performed and calculates the indexes that need to be passed to the dp_ram. Reading and writing are perfomed by two seperate FSM's in this file. This feeder outputs seperate indexes for reading and writing and has suitable control signals to indicate which part of the reading or writing it is currently on. 
4. feeder_tb.sv --> Testbench for checking feeder.sv. This testbench takes an input file (myfile4.txt) which is the input stream of data for the input tensor at a layer. This testbench has an output file (OUTPUT.txt) which consists of the output stream of data from the dp_ram, corresponding to the indexes determined and sent to the dp_ram by the feeder. This output file (OUTPUT.txt) needs to be checked with the correct output file in python, which is in the python code part of this repository.  
 
 This input data is streamed in the form : IC x Iw x Ih, i.e. first all the channels of a (w,h) index in the input tensor are streamed,  followed by all the channels in (w+1,h) and so on till (w+n,h), after which the next row of the input tensor is streamed in a similar manner, (:, :, h+1). 
