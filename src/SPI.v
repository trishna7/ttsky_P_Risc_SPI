`default_nettype none

module SPI_Controller (
    input wire CLK,
    input wire reset,
    input wire WE,              // Write enable from memory stage
    input wire [31:0] A,        // Memory address
    input wire [31:0] WD,       // Write data
    output reg [31:0] RD,       // Read data
    output reg data_ready,      // Data ready flag
    input wire start_transaction, // Start SPI transaction
    
    // SPI interface pins
    output reg spi_clk,
    output reg spi_mosi,
    input wire spi_miso,
    output reg spi_cs_n
);

    // SPI Parameters
    parameter SPI_CLK_DIV = 8;  // SPI clock divider (system_clk / SPI_CLK_DIV)
    parameter SPI_MODE = 0;     // SPI Mode 0 (CPOL=0, CPHA=0)
    
    // 25Q32 SPI Flash Commands
    parameter CMD_READ = 8'h03;       // Read data
    parameter CMD_WRITE_ENABLE = 8'h06; // Write enable
    parameter CMD_PAGE_PROGRAM = 8'h02; // Page program
    parameter CMD_SECTOR_ERASE = 8'hD8; // Sector erase
    parameter CMD_READ_STATUS = 8'h05;  // Read status register
    
    // State machine
    // SPI State parameters
parameter IDLE = 4'b0000;
parameter START_WRITE_EN = 4'b0001;
parameter SEND_WRITE_EN = 4'b0010;
parameter START_READ = 4'b0011;
parameter SEND_READ_CMD = 4'b0100;
parameter SEND_READ_ADDR = 4'b0101;
parameter READ_DATA = 4'b0110;
parameter START_WRITE = 4'b0111;
parameter SEND_WRITE_CMD = 4'b1000;
parameter SEND_WRITE_ADDR = 4'b1001;
parameter WRITE_DATA = 4'b1010;
parameter CHECK_STATUS = 4'b1011;
parameter DONE = 4'b1100;
parameter ERROR = 4'b1101;

reg [3:0] current_state, next_state;
    
    // Internal registers
    reg [7:0] tx_byte;
    reg [7:0] rx_byte;
    reg [31:0] address_reg;
    reg [31:0] data_reg;
    reg [31:0] read_data_reg;
    reg [4:0] bit_counter;
    reg [4:0] byte_counter;
    reg [7:0] clk_counter;
    reg operation_write;
    reg transaction_active;
    
    // Clock generation for SPI
    reg spi_clk_enable;
    reg [7:0] spi_clk_div_counter;
    
    // Initialize all registers
    initial begin
        spi_clk = 1'b0;
        spi_mosi = 1'b0;
        spi_cs_n = 1'b1;
        RD = 32'b0;
        data_ready = 1'b0;
        current_state = IDLE;
        tx_byte = 8'b0;
        rx_byte = 8'b0;
        address_reg = 32'b0;
        data_reg = 32'b0;
        read_data_reg = 32'b0;
        bit_counter = 5'b0;
        byte_counter = 5'b0;
        clk_counter = 8'b0;
        operation_write = 1'b0;
        transaction_active = 1'b0;
        spi_clk_enable = 1'b0;
        spi_clk_div_counter = 8'b0;
    end
    
    // SPI Clock generation
    always @(posedge CLK or posedge reset) begin
        if (reset) begin
            spi_clk_div_counter <= 8'b0;
            spi_clk <= 1'b0;
        end else if (spi_clk_enable) begin
            if (spi_clk_div_counter >= (SPI_CLK_DIV/2 - 1)) begin
                spi_clk <= ~spi_clk;
                spi_clk_div_counter <= 8'b0;
            end else begin
                spi_clk_div_counter <= spi_clk_div_counter + 1;
            end
        end else begin
            spi_clk <= 1'b0;
        end
    end
    
    // Main state machine
    always @(posedge CLK or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            spi_cs_n <= 1'b1;
            spi_mosi <= 1'b0;
            data_ready <= 1'b0;
            RD <= 32'b0;
            transaction_active <= 1'b0;
            spi_clk_enable <= 1'b0;
            bit_counter <= 5'b0;
            byte_counter <= 5'b0;
            address_reg <= 32'b0;
            data_reg <= 32'b0;
            read_data_reg <= 32'b0;
            operation_write <= 1'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    spi_cs_n <= 1'b1;
                    spi_clk_enable <= 1'b0;
                    data_ready <= 1'b0;
                    transaction_active <= 1'b0;
                    
                    if (start_transaction) begin
                        address_reg <= A;
                        data_reg <= WD;
                        operation_write <= WE;
                        transaction_active <= 1'b1;
                    end
                end
                
                START_WRITE_EN: begin
                    if (operation_write) begin
                        spi_cs_n <= 1'b0;
                        spi_clk_enable <= 1'b1;
                        tx_byte <= CMD_WRITE_ENABLE;
                        bit_counter <= 8;
                    end
                end
                
                SEND_WRITE_EN: begin
                    if (spi_clk && bit_counter > 0) begin
                        spi_mosi <= tx_byte[7];
                        tx_byte <= {tx_byte[6:0], 1'b0};
                        bit_counter <= bit_counter - 1;
                    end
                end
                
                START_READ: begin
                    if (!operation_write) begin
                        spi_cs_n <= 1'b0;
                        spi_clk_enable <= 1'b1;
                        tx_byte <= CMD_READ;
                        bit_counter <= 8;
                        byte_counter <= 0;
                    end
                end
                
                SEND_READ_CMD: begin
                    if (spi_clk && bit_counter > 0) begin
                        spi_mosi <= tx_byte[7];
                        tx_byte <= {tx_byte[6:0], 1'b0};
                        bit_counter <= bit_counter - 1;
                    end
                end
                
                SEND_READ_ADDR: begin
                    if (bit_counter == 0) begin
                        if (byte_counter < 3) begin
                            bit_counter <= 8;
                            case (byte_counter)
                                0: tx_byte <= address_reg[23:16];
                                1: tx_byte <= address_reg[15:8];
                                2: tx_byte <= address_reg[7:0];
                            endcase
                            byte_counter <= byte_counter + 1;
                        end
                    end else if (spi_clk) begin
                        spi_mosi <= tx_byte[7];
                        tx_byte <= {tx_byte[6:0], 1'b0};
                        bit_counter <= bit_counter - 1;
                    end
                end
                
                READ_DATA: begin
                    if (bit_counter == 0) begin
                        if (byte_counter < 4) begin
                            bit_counter <= 8;
                            byte_counter <= byte_counter + 1;
                        end
                    end else if (~spi_clk) begin  // Read on falling edge
                        rx_byte <= {rx_byte[6:0], spi_miso};
                        bit_counter <= bit_counter - 1;
                        if (bit_counter == 1) begin
                            case (byte_counter)
                                1: read_data_reg[31:24] <= {rx_byte[6:0], spi_miso};
                                2: read_data_reg[23:16] <= {rx_byte[6:0], spi_miso};
                                3: read_data_reg[15:8] <= {rx_byte[6:0], spi_miso};
                                4: read_data_reg[7:0] <= {rx_byte[6:0], spi_miso};
                            endcase
                        end
                    end
                end
                
                START_WRITE: begin
                    if (operation_write && byte_counter < 3) begin
                        spi_cs_n <= 1'b0;
                        spi_clk_enable <= 1'b1;
                        tx_byte <= CMD_PAGE_PROGRAM;
                        bit_counter <= 8;
                        byte_counter <= 0;
                    end
                end
                
                SEND_WRITE_CMD: begin
                    if (spi_clk && bit_counter > 0) begin
                        spi_mosi <= tx_byte[7];
                        tx_byte <= {tx_byte[6:0], 1'b0};
                        bit_counter <= bit_counter - 1;
                    end
                end
                
                SEND_WRITE_ADDR: begin
                    if (bit_counter == 0) begin
                        if (byte_counter < 3) begin
                            bit_counter <= 8;
                            case (byte_counter)
                                0: tx_byte <= address_reg[23:16];
                                1: tx_byte <= address_reg[15:8];
                                2: tx_byte <= address_reg[7:0];
                            endcase
                            byte_counter <= byte_counter + 1;
                        end
                    end else if (spi_clk) begin
                        spi_mosi <= tx_byte[7];
                        tx_byte <= {tx_byte[6:0], 1'b0};
                        bit_counter <= bit_counter - 1;
                    end
                end
                
                WRITE_DATA: begin
                    if (bit_counter == 0) begin
                        if (byte_counter < 4) begin
                            bit_counter <= 8;
                            case (byte_counter)
                                0: tx_byte <= data_reg[31:24];
                                1: tx_byte <= data_reg[23:16];
                                2: tx_byte <= data_reg[15:8];
                                3: tx_byte <= data_reg[7:0];
                            endcase
                            byte_counter <= byte_counter + 1;
                        end
                    end else if (spi_clk) begin
                        spi_mosi <= tx_byte[7];
                        tx_byte <= {tx_byte[6:0], 1'b0};
                        bit_counter <= bit_counter - 1;
                    end
                end
                
                DONE: begin
                    spi_cs_n <= 1'b1;
                    spi_clk_enable <= 1'b0;
                    data_ready <= 1'b1;
                    if (!operation_write) begin
                        RD <= read_data_reg;
                    end
                end
                
                ERROR: begin
                    spi_cs_n <= 1'b1;
                    spi_clk_enable <= 1'b0;
                    data_ready <= 1'b1;
                    RD <= 32'hDEADBEEF; // Error indicator
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start_transaction) begin
                    if (WE)
                        next_state = START_WRITE_EN;
                    else
                        next_state = START_READ;
                end
            end
            
            START_WRITE_EN: next_state = SEND_WRITE_EN;
            
            SEND_WRITE_EN: begin
                if (bit_counter == 0)
                    next_state = START_WRITE;
            end
            
            START_READ: next_state = SEND_READ_CMD;
            
            SEND_READ_CMD: begin
                if (bit_counter == 0)
                    next_state = SEND_READ_ADDR;
            end
            
            SEND_READ_ADDR: begin
                if (bit_counter == 0 && byte_counter >= 3)
                    next_state = READ_DATA;
            end
            
            READ_DATA: begin
                if (bit_counter == 0 && byte_counter >= 4)
                    next_state = DONE;
            end
            
            START_WRITE: next_state = SEND_WRITE_CMD;
            
            SEND_WRITE_CMD: begin
                if (bit_counter == 0)
                    next_state = SEND_WRITE_ADDR;
            end
            
            SEND_WRITE_ADDR: begin
                if (bit_counter == 0 && byte_counter >= 3)
                    next_state = WRITE_DATA;
            end
            
            WRITE_DATA: begin
                if (bit_counter == 0 && byte_counter >= 4)
                    next_state = DONE;
            end
            
            DONE: begin
                if (!transaction_active)
                    next_state = IDLE;
            end
            
            ERROR: next_state = IDLE;
            
            default: next_state = ERROR;
        endcase
    end

endmodule