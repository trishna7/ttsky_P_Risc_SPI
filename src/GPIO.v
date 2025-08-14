`default_nettype none

module GPIO (
    input CLK,
    input reset,
    input WE,           // Write enable from memory stage
    input [31:0] A,     // Memory-mapped address
    input [31:0] WD,    // Write data
    output reg [31:0] RD, // Read data
    output reg gpio_pin // Single GPIO pin
);

    parameter GPIO_ADDR = 32'h80000000; // Memory-mapped address

    // Proper initialization
    initial begin
        gpio_pin = 1'b0;
        RD = 32'b0;
    end

    always @(posedge CLK or posedge reset) begin
        if (reset) begin
            gpio_pin <= 1'b0;
            RD <= 32'b0;
        end else begin
            // Read operation - always provide current GPIO state
            RD <= (A == GPIO_ADDR) ? {31'b0, gpio_pin} : 32'b0;
            
            // Write operation - only update on valid address and write enable
            if (WE && (A == GPIO_ADDR)) begin
                gpio_pin <= WD[0]; // Only use LSB
            end
        end
    end

endmodule