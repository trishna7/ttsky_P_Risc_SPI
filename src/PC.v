`default_nettype none

module PC (
    input wire CLK,                      // clock signal
    input reset,                         // Standardized reset (active high)
    input wire EN,                       // EN signal 
    input PCSrcE,
    output wire [31:0] PCFI,             // next pc value (input pc value)
    input wire [31:0] PCTargetE,         // output of pc + imm or rs1 + imm
    input wire [31:0] PCPlus4F,          // PC + 4
    output reg [31:0] PCF                // Current PC value 
);

    assign PCFI = PCSrcE ? PCTargetE : PCPlus4F;

    // Proper initialization
    initial begin
        PCF = 32'b0; // Initialize PC to 0
    end 
    
    // Standardized reset logic - active high
    always @(posedge CLK or posedge reset) begin
        if (reset)
            PCF <= 32'b0;            // PC to 0
        else if (EN)
            PCF <= PCFI;             // Update PC if enabled
    end

endmodule