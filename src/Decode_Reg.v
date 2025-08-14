`default_nettype none

module Decode_Reg (
    //input
    input CLR,              //to clear execute register
    input CLK,              //clock
    input EN,               //active high enable

    input [31:0] Instr,
    input [31:0] PCF,
    input [31:0] PCPlus4F,


    output reg [31:0] InstrD,
    output reg [31:0] PCD,
    output reg [31:0] PCPlus4D

);

always @(posedge CLK or posedge CLR) begin

    if (CLR) begin
        InstrD <= 32'b0;
        PCD <= 32'b0;
        PCPlus4D <= 32'b0;
    end
    else if (EN) begin

    InstrD <= Instr;
    PCD <= PCF;
    PCPlus4D <= PCPlus4F;
    end

end

endmodule