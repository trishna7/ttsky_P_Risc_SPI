`default_nettype none
module Registers (
    input CLK,
   // input reset,
    // SOURCE AND DESTIDATION REGISTER ADDRESS
    input [4:0] A1,           //rs1
    input [4:0] A2,             //rs2
    input [4:0] A3,             //rd
    // read write enable
    input WE3,                  //write enable
    input [31:0] WD3,           //write_data

    // outputs from register
    output [31:0] RD1,          //read_data1
    output [31:0] RD2           //read_data2
);
    // Core storage
    reg [31:0] reg_file [1:18];
    
    assign RD1 = (A1 == 5'b0) ? 32'b0 : reg_file[A1];
    assign RD2 = (A2 == 5'b0) ? 32'b0 : reg_file[A2];
    //simulation
//     initial begin
//     for (integer i = 0; i < 16; i = i + 1)
//         reg_file[i] = 32'b0;  // Initialize all registers to 0
// end

    
    always @(negedge CLK) begin
    if (WE3 && A3 != 0) begin
        // if (reg_file[A3] !== WD3) begin  // Only log changes
        //     $display("RegWrite: x%0d = %h (prev %h) @%0t", 
        //             A3, WD3, reg_file[A3], $time);
        // end
        reg_file[A3] <= WD3;
    end
end

endmodule
