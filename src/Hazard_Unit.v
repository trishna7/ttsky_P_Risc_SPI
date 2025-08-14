`default_nettype none

module Hazard_Unit(
    // Source and destination regs execute stage
    input  [4:0] Rs1E,
    input  [4:0] Rs2E,
    input  [4:0] RdE,
    input  [4:0] RdM,
    input  [4:0] RdW,

    // Source and destination regs decode stage
    input  [4:0] Rs1D,
    input  [4:0] Rs2D,

    input PCSrcE,
    input [1:0] ResultSrcE,
    input RegWriteM,
    input RegWriteW,

    // Outputs
    output reg StallF,
    output reg StallD,
    output reg FlushD,
    output reg FlushE,
    output reg [1:0] ForwardAE,
    output reg [1:0] ForwardBE
);

    reg lwStall;
    
    // Proper initialization
    initial begin
        StallF = 1'b0;
        StallD = 1'b0;
        FlushD = 1'b0;
        FlushE = 1'b0;
        ForwardAE = 2'b00;
        ForwardBE = 2'b00;
        lwStall = 1'b0;
    end

    always @(*) begin
        // Load-use hazard detection
        lwStall = (ResultSrcE == 2'b01) && ((Rs1D == RdE && Rs1D != 5'b0) || (Rs2D == RdE && Rs2D != 5'b0));

        // Stall and flush logic
        StallF = lwStall;
        StallD = lwStall;
        FlushD = PCSrcE;
        FlushE = lwStall || PCSrcE;

        // ForwardAE logic with proper zero register handling
        if ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'b0))
            ForwardAE = 2'b10;  // Forward from Memory stage
        else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'b0))
            ForwardAE = 2'b01;  // Forward from Writeback stage
        else
            ForwardAE = 2'b00;  // No forwarding

        // ForwardBE logic with proper zero register handling    
        if ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'b0))
            ForwardBE = 2'b10;  // Forward from Memory stage
        else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'b0))
            ForwardBE = 2'b01;  // Forward from Writeback stage
        else
            ForwardBE = 2'b00;  // No forwarding
    end

endmodule