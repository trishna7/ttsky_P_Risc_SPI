`default_nettype none

// SIGNIFICANTLY REDUCED External Memory Controller for area savings
module External_Memory_Controller (
    input wire CLK,
    input wire reset,
    
    // Processor interface
    input wire WE,
    input wire [31:0] A,
    input wire [31:0] WD,
    output reg [31:0] RD,
    output reg mem_ready,
    
    // SPI interface pins
    output wire spi_clk,
    output wire spi_mosi,
    input wire spi_miso,
    output wire spi_cs_n
);

    // MINIMAL cache for area savings
    parameter CACHE_SIZE = 2;  // Reduced from 16 to 2!
    reg [31:0] cache_data [0:1];
    reg [31:0] cache_addr [0:1]; 
    reg cache_valid [0:1];
    reg cache_lru;  // Single bit for 2-entry cache
    
    // Simple 2-state controller
    reg state;  // 0=IDLE, 1=ACTIVE
    parameter IDLE = 1'b0, ACTIVE = 1'b1;
    
    // SPI Controller interface - simplified
    wire spi_data_ready;
    reg spi_start;
    wire [31:0] spi_read_data;
    reg [31:0] spi_address;
    reg [31:0] spi_write_data;
    reg spi_write_enable;
    
    // Internal registers - minimal set
    reg [31:0] current_address;
    reg [31:0] current_write_data;
    reg current_we;
    reg cache_hit;
    reg operation_pending;
    
    // Initialize
    initial begin
        state = IDLE;
        mem_ready = 1'b1;
        RD = 32'b0;
        spi_start = 1'b0;
        cache_lru = 1'b0;
        operation_pending = 1'b0;
        
        // Initialize small cache
        cache_data[0] = 32'b0;
        cache_data[1] = 32'b0;
        cache_addr[0] = 32'hFFFFFFFF;
        cache_addr[1] = 32'hFFFFFFFF;
        cache_valid[0] = 1'b0;
        cache_valid[1] = 1'b0;
    end
    
    // MUCH SIMPLER SPI Controller instantiation
    Simple_SPI_Controller spi_ctrl (
        .CLK(CLK),
        .reset(reset),
        .WE(spi_write_enable),
        .A(spi_address),
        .WD(spi_write_data),
        .RD(spi_read_data),
        .data_ready(spi_data_ready),
        .start_transaction(spi_start),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
    
    // Simple cache lookup - just 2 entries
    always @(*) begin
        cache_hit = 1'b0;
        if (cache_valid[0] && (cache_addr[0] == current_address)) begin
            cache_hit = 1'b1;
        end else if (cache_valid[1] && (cache_addr[1] == current_address)) begin
            cache_hit = 1'b1;
        end
    end
    
    // Simplified state machine
    always @(posedge CLK or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            mem_ready <= 1'b1;
            RD <= 32'b0;
            spi_start <= 1'b0;
            operation_pending <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    mem_ready <= 1'b1;
                    spi_start <= 1'b0;
                    
                    if ((WE || !mem_ready) && !operation_pending) begin
                        current_address <= A;
                        current_write_data <= WD;
                        current_we <= WE;
                        operation_pending <= 1'b1;
                        mem_ready <= 1'b0;
                        
                        // Check cache immediately
                        if (cache_hit && !WE) begin
                            // Cache hit - return data immediately
                            RD <= cache_valid[0] && (cache_addr[0] == A) ? 
                                  cache_data[0] : cache_data[1];
                            mem_ready <= 1'b1;
                            operation_pending <= 1'b0;
                        end else begin
                            // Cache miss or write - go to SPI
                            state <= ACTIVE;
                            spi_address <= A;
                            spi_write_data <= WD;
                            spi_write_enable <= WE;
                            spi_start <= 1'b1;
                        end
                    end
                end
                
                ACTIVE: begin
                    spi_start <= 1'b0;
                    if (spi_data_ready) begin
                        if (!current_we) begin
                            RD <= spi_read_data;
                            // Update cache - simple replacement
                            cache_data[cache_lru] <= spi_read_data;
                            cache_addr[cache_lru] <= current_address;
                            cache_valid[cache_lru] <= 1'b1;
                            cache_lru <= ~cache_lru;  // Toggle between 0 and 1
                        end
                        mem_ready <= 1'b1;
                        operation_pending <= 1'b0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule

// MUCH SIMPLER SPI Controller
module Simple_SPI_Controller (
    input wire CLK,
    input wire reset,
    input wire WE,
    input wire [31:0] A,
    input wire [31:0] WD,
    output reg [31:0] RD,
    output reg data_ready,
    input wire start_transaction,
    
    output reg spi_clk,
    output reg spi_mosi,
    input wire spi_miso,
    output reg spi_cs_n
);

    // Simple 2-state machine
    reg state; // 0=IDLE, 1=ACTIVE
    reg [5:0] bit_counter;
    reg [7:0] spi_clk_div;
    reg [31:0] shift_out;
    reg [31:0] shift_in;
    
    initial begin
        spi_clk = 1'b0;
        spi_mosi = 1'b0;
        spi_cs_n = 1'b1;
        RD = 32'b0;
        data_ready = 1'b0;
        state = 1'b0; // IDLE
        bit_counter = 6'b0;
        spi_clk_div = 8'b0;
    end
    
    always @(posedge CLK or posedge reset) begin
        if (reset) begin
            state <= 1'b0;
            spi_cs_n <= 1'b1;
            spi_clk <= 1'b0;
            data_ready <= 1'b0;
            bit_counter <= 6'b0;
            spi_clk_div <= 8'b0;
        end else begin
            // Simple SPI clock generation
            spi_clk_div <= spi_clk_div + 1;
            if (spi_clk_div[3:0] == 4'hF && state == 1'b1) begin  // Divide by 16
                spi_clk <= ~spi_clk;
            end
            
            case (state)
                1'b0: begin // IDLE
                    spi_cs_n <= 1'b1;
                    data_ready <= 1'b0;
                    if (start_transaction) begin
                        state <= 1'b1;
                        spi_cs_n <= 1'b0;
                        bit_counter <= 32;
                        shift_out <= WE ? {8'h02, A[23:0]} : {8'h03, A[23:0]}; // Simple read/write commands
                        shift_in <= 32'b0;
                    end
                end
                
                1'b1: begin // ACTIVE
                    if (spi_clk_div[3:0] == 4'hF) begin
                        if (bit_counter > 0) begin
                            spi_mosi <= shift_out[31];
                            shift_out <= {shift_out[30:0], 1'b0};
                            shift_in <= {shift_in[30:0], spi_miso};
                            bit_counter <= bit_counter - 1;
                        end else begin
                            RD <= shift_in;
                            data_ready <= 1'b1;
                            spi_cs_n <= 1'b1;
                            state <= 1'b0;
                        end
                    end
                end
            endcase
        end
    end
    
endmodule