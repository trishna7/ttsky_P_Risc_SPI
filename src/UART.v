`default_nettype none

module UART (
    input wire CLK,           // System clock
    input wire reset,         // Reset signal
    input wire RX,            // UART receive line
    output reg TX,            // UART transmit line
    input wire [31:0] A,      // Memory-mapped address
    input wire [31:0] WD,     // Write data
    input wire WE,            // Write enable
    output reg [31:0] RD,     // Read data
    output reg imem_WE,       // Instruction memory write enable
    output reg [31:0] imem_A, // Instruction memory address
    output reg [31:0] imem_WD,// Instruction memory write data
    output reg cpu_stall,     // Stall CPU during programming
    output reg prog_mode      // Programming mode active
);

    // UART parameters - FIXED for Tiny Tapeout
    parameter CLK_FREQ = 50_000_000; // 50 MHz (Tiny Tapeout standard)
    parameter BAUD_RATE = 9600;      // Reduced for reliability
    localparam BAUD_COUNT = CLK_FREQ / BAUD_RATE; // Clock cycles per bit
    
    // Bounds checking for baud count
    localparam ACTUAL_BAUD_COUNT = (BAUD_COUNT > 0) ? BAUD_COUNT : 1;

    // Memory-mapped addresses
    parameter UART_DATA = 32'h80000004;  // Data register
    parameter UART_CTRL = 32'h80000008;  // Control register (bit 0: start TX, bit 1: prog mode)
    parameter UART_STATUS = 32'h8000000C;// Status register (bit 0: RX ready, bit 1: TX busy)

    // Internal registers
    reg [31:0] rx_data;       // Received data
    reg [31:0] tx_data;       // Data to transmit
    reg rx_ready;             // RX data ready
    reg tx_busy;              // TX in progress
    reg [7:0] rx_byte;        // Current byte being received
    reg [7:0] tx_byte;        // Current byte being transmitted
    reg [31:0] rx_buffer;     // Buffer for 32-bit data
    reg [2:0] byte_count;     // Count received/transmitted bytes
    reg [31:0] imem_addr;     // Instruction memory address for programming

    // UART state machines
    reg [3:0] rx_state;       // RX state
    reg [3:0] tx_state;       // TX state
    reg [31:0] rx_baud_counter;  // RX Baud rate counter
    reg [31:0] tx_baud_counter;  // TX Baud rate counter
    reg [3:0] rx_bit_counter;    // RX Bit counter
    reg [3:0] tx_bit_counter;    // TX Bit counter

    // RX states
    localparam RX_IDLE = 4'd0, RX_START = 4'd1, RX_DATA = 4'd2, RX_STOP = 4'd3;
    // TX states
    localparam TX_IDLE = 4'd0, TX_START = 4'd1, TX_DATA = 4'd2, TX_STOP = 4'd3;

    // Proper initialization
    initial begin
        TX = 1'b1;           // UART idle high
        RD = 32'b0;
        imem_WE = 1'b0;
        imem_A = 32'b0;
        imem_WD = 32'b0;
        cpu_stall = 1'b0;
        prog_mode = 1'b0;
        
        // Internal registers
        rx_data = 32'b0;
        tx_data = 32'b0;
        rx_ready = 1'b0;
        tx_busy = 1'b0;
        rx_state = RX_IDLE;
        tx_state = TX_IDLE;
        rx_byte = 8'b0;
        tx_byte = 8'b0;
        rx_buffer = 32'b0;
        byte_count = 3'b0;
        imem_addr = 32'b0;
        rx_baud_counter = 32'b0;
        tx_baud_counter = 32'b0;
        rx_bit_counter = 4'b0;
        tx_bit_counter = 4'b0;
    end

    // Combined RX and control logic - SINGLE ALWAYS BLOCK
    always @(posedge CLK or posedge reset) begin
        if (reset) begin
            // RX signals
            rx_state <= RX_IDLE;
            rx_data <= 32'b0;
            rx_buffer <= 32'b0;
            rx_byte <= 8'b0;
            byte_count <= 3'b0;
            rx_ready <= 1'b0;
            rx_baud_counter <= 32'b0;
            rx_bit_counter <= 4'b0;
            
            // Control signals
            imem_WE <= 1'b0;
            imem_A <= 32'b0;
            imem_WD <= 32'b0;
            imem_addr <= 32'b0;
            cpu_stall <= 1'b0;
            prog_mode <= 1'b0;
            
            // Memory-mapped read data
            RD <= 32'b0;
        end else begin
            // Default assignments
            imem_WE <= 1'b0;  // Clear by default
            
            // Handle memory-mapped writes first
            if (WE && A == UART_CTRL) begin
                prog_mode <= WD[1]; // Set/reset programming mode
                cpu_stall <= WD[1];
                if (WD[1]) imem_addr <= 32'b0; // Reset address on entering prog mode
            end
            
            // Handle memory-mapped reads
            case (A)
                UART_DATA: RD <= rx_data;
                UART_STATUS: RD <= {30'b0, tx_busy, rx_ready};
                default: RD <= 32'b0;
            endcase
            
            // Clear rx_ready when data is read
            if (A == UART_DATA) rx_ready <= 1'b0;
            
            // RX State Machine
            case (rx_state)
                RX_IDLE: begin
                    if (RX == 1'b0) begin // Start bit detected
                        rx_state <= RX_START;
                        rx_baud_counter <= ACTUAL_BAUD_COUNT / 2; // Sample at middle of bit
                    end
                end
                RX_START: begin
                    if (rx_baud_counter == 0) begin
                        if (RX == 1'b0) begin
                            rx_state <= RX_DATA;
                            rx_bit_counter <= 8;
                            rx_baud_counter <= ACTUAL_BAUD_COUNT;
                        end else begin
                            rx_state <= RX_IDLE;
                        end
                    end else begin
                        rx_baud_counter <= rx_baud_counter - 1;
                    end
                end
                RX_DATA: begin
                    if (rx_baud_counter == 0) begin
                        rx_byte[7:0] <= {RX, rx_byte[7:1]};
                        rx_bit_counter <= rx_bit_counter - 1;
                        rx_baud_counter <= ACTUAL_BAUD_COUNT;
                        if (rx_bit_counter == 1) begin
                            rx_state <= RX_STOP;
                        end
                    end else begin
                        rx_baud_counter <= rx_baud_counter - 1;
                    end
                end
                RX_STOP: begin
                    if (rx_baud_counter == 0) begin
                        rx_buffer <= {rx_byte, rx_buffer[31:8]};
                        byte_count <= byte_count + 1;
                        rx_state <= RX_IDLE;
                        if (byte_count == 3) begin
                            rx_data <= {rx_byte, rx_buffer[31:8]};
                            rx_ready <= 1'b1;
                            byte_count <= 3'b0; // Reset for next 32-bit word
                            if (prog_mode) begin
                                imem_WE <= 1'b1;
                                imem_A <= imem_addr;
                                imem_WD <= {rx_byte, rx_buffer[31:8]};
                                imem_addr <= imem_addr + 4;
                            end
                        end
                        rx_baud_counter <= ACTUAL_BAUD_COUNT;
                    end else begin
                        rx_baud_counter <= rx_baud_counter - 1;
                    end
                end
            endcase
        end
    end

    // TX logic - SEPARATE ALWAYS BLOCK (no conflicts)
    reg [2:0] tx_byte_count;
    
    always @(posedge CLK or posedge reset) begin
        if (reset) begin
            tx_state <= TX_IDLE;
            TX <= 1'b1; // Idle high
            tx_busy <= 1'b0;
            tx_byte <= 8'b0;
            tx_byte_count <= 3'b0;
            tx_bit_counter <= 4'b0;
            tx_baud_counter <= 32'b0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    TX <= 1'b1;
                    if (WE && A == UART_CTRL && WD[0]) begin // Start TX
                        tx_data <= RD; // Use last read data
                        tx_byte <= RD[7:0];
                        tx_state <= TX_START;
                        tx_busy <= 1'b1;
                        tx_byte_count <= 3'b0;
                        tx_baud_counter <= ACTUAL_BAUD_COUNT;
                    end
                end
                TX_START: begin
                    TX <= 1'b0; // Start bit
                    if (tx_baud_counter == 0) begin
                        tx_state <= TX_DATA;
                        tx_bit_counter <= 8;
                        tx_baud_counter <= ACTUAL_BAUD_COUNT;
                    end else begin
                        tx_baud_counter <= tx_baud_counter - 1;
                    end
                end
                TX_DATA: begin
                    TX <= tx_byte[0];
                    if (tx_baud_counter == 0) begin
                        tx_byte <= {1'b0, tx_byte[7:1]};
                        tx_bit_counter <= tx_bit_counter - 1;
                        tx_baud_counter <= ACTUAL_BAUD_COUNT;
                        if (tx_bit_counter == 1) begin
                            tx_state <= TX_STOP;
                        end
                    end else begin
                        tx_baud_counter <= tx_baud_counter - 1;
                    end
                end
                TX_STOP: begin
                    TX <= 1'b1; // Stop bit
                    if (tx_baud_counter == 0) begin
                        if (tx_byte_count == 3) begin
                            tx_state <= TX_IDLE;
                            tx_busy <= 1'b0;
                        end else begin
                            tx_byte_count <= tx_byte_count + 1;
                            tx_byte <= tx_data[8*(tx_byte_count+1)+:8];
                            tx_state <= TX_START;
                            tx_baud_counter <= ACTUAL_BAUD_COUNT;
                        end
                    end else begin
                        tx_baud_counter <= tx_baud_counter - 1;
                    end
                end
            endcase
        end
    end

endmodule