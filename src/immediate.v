`default_nettype none

module immediate (
    input wire [31:7] InstrD,
    input wire [2:0] ImmSrcD,
    output reg [31:0] ImmExtD
);

always @(*) begin
    case (ImmSrcD)
        3'b000 : ImmExtD = {{20{InstrD[31]}}, InstrD[31:20]}; //i type, making it 32 bit with addition of 20 bits of signed bit to 12 bit
        3'b001 : ImmExtD = {{20{InstrD[31]}}, InstrD[31:25], InstrD[11:7]}; // s-type
        3'b010 : ImmExtD = {{20{InstrD[31]}}, InstrD[7], InstrD[30:25], InstrD[11:8], 1'b0}; // b type
        3'b011 : ImmExtD = {{12{InstrD[31]}}, InstrD[19:12], InstrD[20], InstrD[30:21], 1'b0}; // j type
        3'b100 : ImmExtD = {InstrD[31:12], 12'b0}; // u type
        default : ImmExtD = 32'b0;
    endcase
end
endmodule
