`default_nettype none

module Instruction_Memory (
    input wire CLK,           // Clock for synchronous writes
    input wire WE,            // Write enable for UART programming
    input wire [31:0] A,      // PC from core or UART address
    input wire [31:0] WD,     // Write data from UART
    output wire [31:0] RD     // Instruction output
);
    // Increased memory size - 256 words (1KB)
    reg [31:0] memory [0:63];
    
    // Bounds checking
    wire address_valid = (A[31:2] < 64);

    // Initialize with default program and clear unused memory
    integer i;
    initial begin
        // Simple GPIO blink program
        memory[0] = 32'h00100093; // addi x1, x0, 1      # Load 1
        memory[1] = 32'h80000337; // lui x6, 0x80000     # GPIO base
        memory[2] = 32'h00000013; // nop                 # Wait
        memory[3] = 32'h00000013; // nop                 # Wait 
        memory[4] = 32'h00132023; // sw x1, 0(x6)        # Write to GPIO
        memory[5] = 32'h00000093; // addi x1, x0, 0      # Load 0
        memory[6] = 32'h00132023; // sw x1, 0(x6)        # Write to GPIO
        memory[7] = 32'hfddff06f; // jal x0, -8          # Jump back
        
        // Initialize remaining memory to NOPs
        for (i = 8; i < 64; i = i + 1) begin
            memory[i] = 32'h00000013; // NOP instruction
        end
    end

    // Synchronous write for UART programming with bounds checking
    always @(posedge CLK) begin
        if (WE && address_valid) begin
            memory[A[31:2]] <= WD;
            // Optional debug output (uncomment for simulation)
            // $display("IMEM Write: addr=%h, data=%h @%0t", A, WD, $time);
        end
    end

    // Asynchronous read with bounds checking
    assign RD = address_valid ? memory[A[31:2]] : 32'h00000013; // NOP if invalid address

endmodule