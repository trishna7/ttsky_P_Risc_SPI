`default_nettype none

module Mem_Reg (
    //input
    input CLK,              //clock

    //control part
    input RegWriteE,
    input [1:0] ResultSrcE,
    input MemWriteE,

    //instruction or Pc inputs
    input [31:0] PCPlus4E,
    input [4:0] RdE,
    input [31:0] UOutE,

    //ALU and register data
    input [31:0] WriteDataE,
    input [31:0] ALUResultE,


    //Control part output
    output reg RegWriteM,
    output reg [1:0] ResultSrcM,
    output reg MemWriteM,

    //ALU and register data output
    output reg [31:0] WriteDataM,       
    output reg [31:0] ALUResultM,       

    //instruction or Pc inputs
    output reg [31:0] PCPlus4M,
    output reg [4:0] RdM,
    output reg [31:0] UOutM
    

);

initial begin
        RegWriteM = 0;
        ResultSrcM = 0;
        MemWriteM = 0;
        WriteDataM =0;
        ALUResultM = 0;
        UOutM = 0;

        RdM = 0;
        PCPlus4M = 0;
end

always @(posedge CLK) begin
    
    RegWriteM <= RegWriteE;
    ResultSrcM <= ResultSrcE;
    MemWriteM <= MemWriteE;
    ALUResultM <= ALUResultE;
    WriteDataM <= WriteDataE;
    UOutM <= UOutE;

    RdM <= RdE;
    PCPlus4M <= PCPlus4E;
   

end

endmodule
