`default_nettype none

module Writeback_Reg (
    //input
    input CLK,              //clock

    //control part
    input RegWriteM,
    input [1:0] ResultSrcM,

    //instruction or Pc inputs
    input [31:0] PCPlus4M,
    input [4:0] RdM,
    input [31:0] UOutM,

    //ALU and memory data
    input [31:0] ReadDataM,
    input [31:0] ALUResultM,


    //Control part output
    output reg RegWriteW,
    output reg [1:0] ResultSrcW,

    //ALU and register data output
    output reg [31:0] ReadDataW,       //read data 1
    output reg [31:0] ALUResultW,       //read data 2

    //instruction or Pc inputs
    output reg [31:0] PCPlus4W,
    output reg [4:0] RdW,
    output reg [31:0] UOutW

);

initial begin
        RegWriteW = 0;
        ResultSrcW = 0;
        ALUResultW = 0;
        ReadDataW = 0;
        UOutW = 0;

        RdW = 0;
        PCPlus4W = 0;
end

always @(posedge CLK) begin
    
    RegWriteW <= RegWriteM;
    ResultSrcW <= ResultSrcM;
    ALUResultW <= ALUResultM;
    ReadDataW <= ReadDataM;
    UOutW <= UOutM;

    RdW <= RdM;
    PCPlus4W <= PCPlus4M;

end

endmodule
